# Start the workbench if it is not already listening.
# API on 127.0.0.1:8765, page on 127.0.0.1:3000.
# Both processes are detached with no console window.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $root 'var'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir 'workbench.log'

function Write-Log([string]$message) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message
    Add-Content -Path $log -Value $line -Encoding UTF8
}

function Test-Listening([int]$port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $client.BeginConnect('127.0.0.1', $port, $null, $null)
        $ok = $connect.AsyncWaitHandle.WaitOne(400)
        if (-not $ok) { return $false }
        $client.EndConnect($connect)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Find-Node {
    $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $fallback = 'E:\soft\node\node.exe'
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    return $null
}

if (-not ('OrBit.HiddenStart' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace OrBit {
    public static class HiddenStart {
        const uint CREATE_NO_WINDOW = 0x08000000;
        const uint CREATE_NEW_PROCESS_GROUP = 0x00000200;
        const int STARTF_USESTDHANDLES = 0x00000100;
        const int STARTF_USESHOWWINDOW = 0x00000001;
        const short SW_HIDE = 0;
        const uint GENERIC_READ = 0x80000000;
        const uint FILE_APPEND_DATA = 0x0004;
        const uint FILE_SHARE_READ = 0x00000001;
        const uint FILE_SHARE_WRITE = 0x00000002;
        const uint OPEN_ALWAYS = 4;
        const uint OPEN_EXISTING = 3;
        const uint FILE_ATTRIBUTE_NORMAL = 0x80;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct STARTUPINFO {
            public int cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public int dwX;
            public int dwY;
            public int dwXSize;
            public int dwYSize;
            public int dwXCountChars;
            public int dwYCountChars;
            public int dwFillAttribute;
            public int dwFlags;
            public short wShowWindow;
            public short cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct PROCESS_INFORMATION {
            public IntPtr hProcess;
            public IntPtr hThread;
            public int dwProcessId;
            public int dwThreadId;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct SECURITY_ATTRIBUTES {
            public int nLength;
            public IntPtr lpSecurityDescriptor;
            public bool bInheritHandle;
        }

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        static extern bool CreateProcess(
            string lpApplicationName,
            StringBuilder lpCommandLine,
            IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes,
            bool bInheritHandles,
            uint dwCreationFlags,
            IntPtr lpEnvironment,
            string lpCurrentDirectory,
            ref STARTUPINFO lpStartupInfo,
            out PROCESS_INFORMATION lpProcessInformation);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        static extern IntPtr CreateFile(
            string lpFileName,
            uint dwDesiredAccess,
            uint dwShareMode,
            ref SECURITY_ATTRIBUTES lpSecurityAttributes,
            uint dwCreationDisposition,
            uint dwFlagsAndAttributes,
            IntPtr hTemplateFile);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool CloseHandle(IntPtr hObject);

        public static int Start(string commandLine, string workingDirectory, string stdoutPath, string stderrPath) {
            var sa = new SECURITY_ATTRIBUTES();
            sa.nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES));
            sa.bInheritHandle = true;

            IntPtr nul = CreateFile("NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, ref sa, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, IntPtr.Zero);
            IntPtr stdout = CreateFile(stdoutPath, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, ref sa, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, IntPtr.Zero);
            IntPtr stderr = CreateFile(stderrPath, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, ref sa, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, IntPtr.Zero);
            if (nul == new IntPtr(-1) || stdout == new IntPtr(-1) || stderr == new IntPtr(-1)) {
                int error = Marshal.GetLastWin32Error();
                CloseIfOpen(nul);
                CloseIfOpen(stdout);
                CloseIfOpen(stderr);
                throw new Win32Exception(error);
            }

            var si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
            si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
            si.wShowWindow = SW_HIDE;
            si.hStdInput = nul;
            si.hStdOutput = stdout;
            si.hStdError = stderr;

            var command = new StringBuilder(commandLine, commandLine.Length + 1);
            PROCESS_INFORMATION pi;
            bool ok = CreateProcess(
                null,
                command,
                IntPtr.Zero,
                IntPtr.Zero,
                true,
                CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP,
                IntPtr.Zero,
                workingDirectory,
                ref si,
                out pi);

            int started = Marshal.GetLastWin32Error();
            CloseIfOpen(nul);
            CloseIfOpen(stdout);
            CloseIfOpen(stderr);
            if (!ok) {
                throw new Win32Exception(started);
            }

            int pid = pi.dwProcessId;
            CloseHandle(pi.hThread);
            CloseHandle(pi.hProcess);
            return pid;
        }

        static void CloseIfOpen(IntPtr handle) {
            if (handle != IntPtr.Zero && handle != new IntPtr(-1)) {
                CloseHandle(handle);
            }
        }
    }
}
'@ -Language CSharp
}

function Start-Hidden([string]$commandLine, [string]$workingDirectory, [string]$name) {
    $stdout = Join-Path $logDir "$name.out.log"
    $stderr = Join-Path $logDir "$name.err.log"
    return [OrBit.HiddenStart]::Start($commandLine, $workingDirectory, $stdout, $stderr)
}

Write-Log 'start requested'

if (-not (Test-Listening 8765)) {
    $python = Join-Path $root '.venv\Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $python)) {
        Write-Log "missing python: $python"
        exit 1
    }
    $server = Join-Path $root 'server'
    $apiCommand = '"{0}" -m uvicorn app:app --app-dir "{1}" --host 127.0.0.1 --port 8765' -f $python, $server
    $apiPid = Start-Hidden $apiCommand $root 'api'
    Write-Log "api starting on 8765 pid $apiPid"
} else {
    Write-Log 'api already listening on 8765'
}

if (-not (Test-Listening 3000)) {
    $node = Find-Node
    $vite = Join-Path $root 'web\node_modules\vite\bin\vite.js'
    if (-not $node) {
        Write-Log 'node.exe not found'
        exit 1
    }
    if (-not (Test-Path -LiteralPath $vite)) {
        Write-Log "missing vite: $vite"
        exit 1
    }
    $pageCommand = '"{0}" "{1}" --host 127.0.0.1 --port 3000 --strictPort' -f $node, $vite
    $pagePid = Start-Hidden $pageCommand (Join-Path $root 'web') 'page'
    Write-Log "page starting on 3000 pid $pagePid"
} else {
    Write-Log 'page already listening on 3000'
}

exit 0
