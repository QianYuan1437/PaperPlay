# Read Unicode shell links without WScript.Shell's ANSI path conversion.
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class PaperPlayShortcut {
  [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
  class ShellLink { }
  [ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IShellLinkW {
    void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int count, IntPtr findData, uint flags);
    void GetIDList(out IntPtr item);
    void SetIDList(IntPtr item);
    void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder text, int count);
    void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string text);
    void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int count);
    void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string path);
    void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder text, int count);
    void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string text);
    void GetHotkey(out short key);
    void SetHotkey(short key);
    void GetShowCmd(out int command);
    void SetShowCmd(int command);
    void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int count, out int index);
  }
  public static string[] Read(string file) {
    object instance = new ShellLink();
    try {
      ((IPersistFile)instance).Load(file, 0);
      var link = (IShellLinkW)instance;
      var target = new StringBuilder(32768);
      var directory = new StringBuilder(32768);
      var icon = new StringBuilder(32768);
      int iconIndex;
      link.GetPath(target, target.Capacity, IntPtr.Zero, 4);
      link.GetWorkingDirectory(directory, directory.Capacity);
      link.GetIconLocation(icon, icon.Capacity, out iconIndex);
      return new[] { target.ToString(), directory.ToString(), icon + "," + iconIndex };
    } finally { Marshal.FinalReleaseComObject(instance); }
  }
}
'@
