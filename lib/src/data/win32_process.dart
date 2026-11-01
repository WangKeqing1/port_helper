import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// 用 Win32 API 直接读进程信息，替掉 PowerShell + WMI。
///
/// 实测：WMI 查单个进程要 730ms（还含 154ms 的 PowerShell 冷启动），
/// 而下面这组 kernel32 调用取几个进程的全部信息在 10ms 以内。
///
/// 走的是 `CreateToolhelp32Snapshot`（一次遍历拿全表，含父进程 PID）
/// 加 `OpenProcess` + `QueryFullProcessImageNameW` / `GetProcessTimes`，
/// 文件描述从 exe 的版本资源里读。
class Win32Process {
  Win32Process._();

  static final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
  static final DynamicLibrary _version = DynamicLibrary.open('version.dll');
  static final DynamicLibrary _advapi32 = DynamicLibrary.open('advapi32.dll');

  // ── kernel32 ────────────────────────────────────────────
  static final _createToolhelp32Snapshot = _kernel32.lookupFunction<
      IntPtr Function(Uint32, Uint32),
      int Function(int, int)>('CreateToolhelp32Snapshot');

  static final _process32First = _kernel32.lookupFunction<
      Int32 Function(IntPtr, Pointer<_ProcessEntry32W>),
      int Function(int, Pointer<_ProcessEntry32W>)>('Process32FirstW');

  static final _process32Next = _kernel32.lookupFunction<
      Int32 Function(IntPtr, Pointer<_ProcessEntry32W>),
      int Function(int, Pointer<_ProcessEntry32W>)>('Process32NextW');

  static final _closeHandle = _kernel32.lookupFunction<
      Int32 Function(IntPtr),
      int Function(int)>('CloseHandle');

  static final _openProcess = _kernel32.lookupFunction<
      IntPtr Function(Uint32, Int32, Uint32),
      int Function(int, int, int)>('OpenProcess');

  static final _queryFullProcessImageName = _kernel32.lookupFunction<
      Int32 Function(IntPtr, Uint32, Pointer<Uint16>, Pointer<Uint32>),
      int Function(int, int, Pointer<Uint16>, Pointer<Uint32>)>(
    'QueryFullProcessImageNameW',
  );

  static final _getProcessTimes = _kernel32.lookupFunction<
      Int32 Function(IntPtr, Pointer<_FileTime>, Pointer<_FileTime>,
          Pointer<_FileTime>, Pointer<_FileTime>),
      int Function(int, Pointer<_FileTime>, Pointer<_FileTime>,
          Pointer<_FileTime>, Pointer<_FileTime>)>('GetProcessTimes');

  // ── version.dll ─────────────────────────────────────────
  static final _getFileVersionInfoSize = _version.lookupFunction<
      Uint32 Function(Pointer<Utf16>, Pointer<Uint32>),
      int Function(Pointer<Utf16>, Pointer<Uint32>)>('GetFileVersionInfoSizeW');

  static final _getFileVersionInfo = _version.lookupFunction<
      Int32 Function(Pointer<Utf16>, Uint32, Uint32, Pointer<Void>),
      int Function(Pointer<Utf16>, int, int, Pointer<Void>)>(
    'GetFileVersionInfoW',
  );

  static final _verQueryValue = _version.lookupFunction<
      Int32 Function(
          Pointer<Void>, Pointer<Utf16>, Pointer<Pointer<Void>>, Pointer<Uint32>),
      int Function(Pointer<Void>, Pointer<Utf16>, Pointer<Pointer<Void>>,
          Pointer<Uint32>)>('VerQueryValueW');

  // ── advapi32（取进程属主）─────────────────────────────────
  static final _openProcessToken = _advapi32.lookupFunction<
      Int32 Function(IntPtr, Uint32, Pointer<IntPtr>),
      int Function(int, int, Pointer<IntPtr>)>('OpenProcessToken');

  static final _getTokenInformation = _advapi32.lookupFunction<
      Int32 Function(IntPtr, Int32, Pointer<Void>, Uint32, Pointer<Uint32>),
      int Function(int, int, Pointer<Void>, int, Pointer<Uint32>)>(
    'GetTokenInformation',
  );

  static final _lookupAccountSid = _advapi32.lookupFunction<
      Int32 Function(Pointer<Utf16>, Pointer<Void>, Pointer<Uint16>,
          Pointer<Uint32>, Pointer<Uint16>, Pointer<Uint32>, Pointer<Int32>),
      int Function(Pointer<Utf16>, Pointer<Void>, Pointer<Uint16>,
          Pointer<Uint32>, Pointer<Uint16>, Pointer<Uint32>, Pointer<Int32>)>(
    'LookupAccountSidW',
  );

  // ── 常量 ────────────────────────────────────────────────
  static const _th32csSnapProcess = 0x00000002;
  static const _processQueryLimitedInformation = 0x1000;
  static const _invalidHandleValue = -1;
  static const _maxPath = 32768;

  /// 1601-01-01 到 1970-01-01 之间的 100ns 数，用来把 FILETIME 转成 Unix 时间。
  static const _epochDelta = 116444736000000000;

  /// 一次快照拿到全表的 PID → (父 PID, 进程名)。
  static Map<int, ProcessSnapshotEntry> snapshot() {
    final out = <int, ProcessSnapshotEntry>{};
    final snap = _createToolhelp32Snapshot(_th32csSnapProcess, 0);
    if (snap == _invalidHandleValue || snap == 0) return out;

    final entry = calloc<_ProcessEntry32W>();
    try {
      entry.ref.dwSize = sizeOf<_ProcessEntry32W>();
      var ok = _process32First(snap, entry) != 0;
      while (ok) {
        final pid = entry.ref.th32ProcessID;
        out[pid] = ProcessSnapshotEntry(
          pid: pid,
          parentPid: entry.ref.th32ParentProcessID,
          name: _readWide(entry.ref.szExeFile, 260),
        );
        ok = _process32Next(snap, entry) != 0;
      }
    } finally {
      calloc.free(entry);
      _closeHandle(snap);
    }
    return out;
  }

  /// 可执行文件完整路径。没有权限时返回 null。
  static String? imagePath(int pid) {
    final handle = _openProcess(_processQueryLimitedInformation, 0, pid);
    if (handle == 0) return null;

    final buffer = calloc<Uint16>(_maxPath);
    final size = calloc<Uint32>();
    try {
      size.value = _maxPath;
      final ok = _queryFullProcessImageName(handle, 0, buffer, size) != 0;
      if (!ok || size.value == 0) return null;
      return buffer.cast<Utf16>().toDartString(length: size.value);
    } finally {
      calloc.free(buffer);
      calloc.free(size);
      _closeHandle(handle);
    }
  }

  /// 进程启动时间。
  static DateTime? startTime(int pid) {
    final handle = _openProcess(_processQueryLimitedInformation, 0, pid);
    if (handle == 0) return null;

    final created = calloc<_FileTime>();
    final exited = calloc<_FileTime>();
    final kernel = calloc<_FileTime>();
    final user = calloc<_FileTime>();
    try {
      final ok = _getProcessTimes(handle, created, exited, kernel, user) != 0;
      if (!ok) return null;
      final low = created.ref.dwLowDateTime;
      final high = created.ref.dwHighDateTime;
      if (low == 0 && high == 0) return null;
      final ticks = (high << 32) | low;
      final micros = (ticks - _epochDelta) ~/ 10;
      if (micros <= 0) return null;
      return DateTime.fromMicrosecondsSinceEpoch(micros);
    } finally {
      calloc.free(created);
      calloc.free(exited);
      calloc.free(kernel);
      calloc.free(user);
      _closeHandle(handle);
    }
  }

  /// 从 exe 的版本资源里读 FileDescription，例如 `Node.js JavaScript Runtime`。
  ///
  /// 语言/代码页组合因 exe 而异，所以先查 `\VarFileInfo\Translation`
  /// 拿到所有组合再逐个试。
  static String? fileDescription(String path) {
    final pathPtr = path.toNativeUtf16();
    final dummy = calloc<Uint32>();
    Pointer<Uint8> data = nullptr;
    try {
      final size = _getFileVersionInfoSize(pathPtr, dummy);
      if (size == 0) return null;

      data = calloc<Uint8>(size);
      if (_getFileVersionInfo(pathPtr, 0, size, data.cast()) == 0) return null;

      final translations = _translations(data);
      for (final t in translations) {
        final value = _queryString(data, t, 'FileDescription');
        if (value != null && value.isNotEmpty) return value;
      }
      // 有的 exe 没有 Translation 表，退回英文表碰运气。
      for (final t in const [(0x0409, 0x04B0), (0x0804, 0x04B0), (0x0000, 0x04B0)]) {
        final value = _queryString(data, t, 'FileDescription');
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    } finally {
      if (data != nullptr) calloc.free(data);
      calloc.free(dummy);
      calloc.free(pathPtr);
    }
  }

  static List<(int, int)> _translations(Pointer<Uint8> data) {
    final block = r'\VarFileInfo\Translation'.toNativeUtf16();
    final out = <(int, int)>[];
    final buffer = calloc<Pointer<Void>>();
    final len = calloc<Uint32>();
    try {
      if (_verQueryValue(data.cast(), block, buffer, len) == 0) return out;
      final count = len.value ~/ 4;
      if (count <= 0) return out;
      final words = buffer.value.cast<Uint16>();
      for (var i = 0; i < count; i++) {
        out.add((words[i * 2], words[i * 2 + 1]));
      }
    } finally {
      calloc.free(block);
      calloc.free(buffer);
      calloc.free(len);
    }
    return out;
  }

  static String? _queryString(Pointer<Uint8> data, (int, int) translation, String key) {
    final lang = translation.$1.toRadixString(16).padLeft(4, '0');
    final codepage = translation.$2.toRadixString(16).padLeft(4, '0');
    final sub = '\\StringFileInfo\\$lang$codepage\\$key'.toNativeUtf16();
    final buffer = calloc<Pointer<Void>>();
    final len = calloc<Uint32>();
    try {
      if (_verQueryValue(data.cast(), sub, buffer, len) == 0) return null;
      if (len.value == 0 || buffer.value == nullptr) return null;
      return buffer.value.cast<Utf16>().toDartString(length: len.value - 1);
    } finally {
      calloc.free(sub);
      calloc.free(buffer);
      calloc.free(len);
    }
  }

  /// 进程属主账户名，例如 `mashiro`。系统进程会返回 `SYSTEM`。
  static String? userName(int pid) {
    final process = _openProcess(_processQueryLimitedInformation, 0, pid);
    if (process == 0) return null;

    final tokenPtr = calloc<IntPtr>();
    try {
      // TOKEN_QUERY = 0x0008
      if (_openProcessToken(process, 0x0008, tokenPtr) == 0) return null;
      final token = tokenPtr.value;
      try {
        return _userFromToken(token);
      } finally {
        _closeHandle(token);
      }
    } finally {
      calloc.free(tokenPtr);
      _closeHandle(process);
    }
  }

  static String? _userFromToken(int token) {
    final needed = calloc<Uint32>();
    try {
      // TokenUser = 1；先用空 buffer 问长度。
      _getTokenInformation(token, 1, nullptr, 0, needed);
      if (needed.value == 0) return null;

      final buffer = calloc<Uint8>(needed.value);
      try {
        if (_getTokenInformation(token, 1, buffer.cast(), needed.value, needed) == 0) {
          return null;
        }
        // TOKEN_USER 的第一个字段就是 PSID。
        final sidAddress = buffer.cast<IntPtr>().value;
        if (sidAddress == 0) return null;
        return _accountName(sidAddress);
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(needed);
    }
  }

  static String? _accountName(int sidAddress) {
    final sid = Pointer<Void>.fromAddress(sidAddress);
    final nameLen = calloc<Uint32>();
    final domainLen = calloc<Uint32>();
    final sidType = calloc<Int32>();
    Pointer<Uint16> name = nullptr;
    Pointer<Uint16> domain = nullptr;
    try {
      // 第一次调用只为拿到所需长度。
      _lookupAccountSid(nullptr, sid, nullptr, nameLen, nullptr, domainLen, sidType);
      if (nameLen.value == 0) return null;

      name = calloc<Uint16>(nameLen.value);
      domain = calloc<Uint16>(domainLen.value == 0 ? 1 : domainLen.value);
      final ok = _lookupAccountSid(
        nullptr,
        sid,
        name,
        nameLen,
        domain,
        domainLen,
        sidType,
      );
      if (ok == 0) return null;
      final text = name.cast<Utf16>().toDartString();
      return text.isEmpty ? null : text;
    } finally {
      if (name != nullptr) calloc.free(name);
      if (domain != nullptr) calloc.free(domain);
      calloc.free(nameLen);
      calloc.free(domainLen);
      calloc.free(sidType);
    }
  }

  static String _readWide(Array<Uint16> chars, int max) {
    final codes = <int>[];
    for (var i = 0; i < max; i++) {
      final c = chars[i];
      if (c == 0) break;
      codes.add(c);
    }
    return String.fromCharCodes(codes);
  }
}

/// 快照里的一条进程记录。
class ProcessSnapshotEntry {
  const ProcessSnapshotEntry({
    required this.pid,
    required this.parentPid,
    required this.name,
  });

  final int pid;
  final int parentPid;
  final String name;
}

final class _ProcessEntry32W extends Struct {
  @Uint32()
  external int dwSize;
  @Uint32()
  external int cntUsage;
  @Uint32()
  external int th32ProcessID;
  @UintPtr()
  external int th32DefaultHeapID;
  @Uint32()
  external int th32ModuleID;
  @Uint32()
  external int cntThreads;
  @Uint32()
  external int th32ParentProcessID;
  @Int32()
  external int pcPriClassBase;
  @Uint32()
  external int dwFlags;
  @Array(260)
  external Array<Uint16> szExeFile;
}

final class _FileTime extends Struct {
  @Uint32()
  external int dwLowDateTime;
  @Uint32()
  external int dwHighDateTime;
}
