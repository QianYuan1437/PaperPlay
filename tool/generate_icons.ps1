$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
public static class PaperPlayIcon {
  static GraphicsPath Round(float x,float y,float w,float h,float r) {
    var p=new GraphicsPath(); p.AddArc(x,y,r*2,r*2,180,90); p.AddArc(x+w-r*2,y,r*2,r*2,270,90);
    p.AddArc(x+w-r*2,y+h-r*2,r*2,r*2,0,90); p.AddArc(x,y+h-r*2,r*2,r*2,90,90); p.CloseFigure(); return p;
  }
  static void Gear(Graphics g,float x,float y,float radius) {
    var points=new PointF[48];
    for(int i=0;i<48;i++){double a=i*Math.PI/24;float r=radius*(i%6==0||i%6==5?.81f:1f);points[i]=new PointF(x+(float)Math.Cos(a)*r,y+(float)Math.Sin(a)*r);}
    using(var p=new GraphicsPath(FillMode.Alternate)){p.AddPolygon(points);p.AddEllipse(x-radius*.43f,y-radius*.43f,radius*.86f,radius*.86f);
      using(var b=new SolidBrush(Color.FromArgb(65,155,120,25)))g.FillPath(b,p);}
  }
  public static void Generate(string directory,bool playing) {
    using(var canvas=new Bitmap(256,256,PixelFormat.Format32bppArgb)){
      using(var g=Graphics.FromImage(canvas)){
        g.SmoothingMode=SmoothingMode.AntiAlias;g.ScaleTransform(4,4);g.Clear(Color.Transparent);
        using(var p=Round(2,2,60,60,16))using(var b=new LinearGradientBrush(new Point(0,0),new Point(64,64),Color.FromArgb(255,247,208),Color.FromArgb(255,232,148)))g.FillPath(b,p);
        using(var p=Round(10,11,44,42,8))using(var pen=new Pen(Color.FromArgb(80,165,130,35),2))g.DrawPath(pen,p);
        Gear(g,23,25,12);Gear(g,42,40,12);
        using(var b=new SolidBrush(Color.FromArgb(255,104,80,19))){
          if(playing){using(var a=Round(22,18,8,29,2))g.FillPath(b,a);using(var a=Round(35,18,8,29,2))g.FillPath(b,a);}
          else {var p=new GraphicsPath();p.AddPolygon(new[]{new PointF(23,17),new PointF(48,32),new PointF(23,47)});using(var pen=new Pen(Color.FromArgb(255,104,80,19),3){LineJoin=LineJoin.Round})g.DrawPath(pen,p);g.FillPath(b,p);p.Dispose();}
        }
      }
      canvas.Save(Path.Combine(directory,playing?"logo_playing.png":"logo.png"),ImageFormat.Png);
      int[] sizes={16,24,32,48,64,128,256};var data=new byte[sizes.Length][];
      for(int i=0;i<sizes.Length;i++)using(var scaled=new Bitmap(sizes[i],sizes[i],PixelFormat.Format32bppArgb)){
        using(var g=Graphics.FromImage(scaled)){g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.DrawImage(canvas,0,0,sizes[i],sizes[i]);}
        using(var ms=new MemoryStream()){scaled.Save(ms,ImageFormat.Png);data[i]=ms.ToArray();}
      }
      using(var stream=File.Create(Path.Combine(directory,playing?"tray_playing.ico":"tray.ico")))using(var w=new BinaryWriter(stream)){
        w.Write((ushort)0);w.Write((ushort)1);w.Write((ushort)sizes.Length);int offset=6+16*sizes.Length;
        for(int i=0;i<sizes.Length;i++){w.Write((byte)(sizes[i]==256?0:sizes[i]));w.Write((byte)(sizes[i]==256?0:sizes[i]));w.Write((byte)0);w.Write((byte)0);w.Write((ushort)1);w.Write((ushort)32);w.Write(data[i].Length);w.Write(offset);offset+=data[i].Length;}
        foreach(var bytes in data)w.Write(bytes);
      }
    }
  }
}
'@
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$assetRoot = Join-Path $projectRoot 'assets'
[PaperPlayIcon]::Generate($assetRoot, $false)
[PaperPlayIcon]::Generate($assetRoot, $true)
Copy-Item -LiteralPath (Join-Path $assetRoot 'tray.ico') -Destination (Join-Path $projectRoot 'windows/runner/resources/app_icon.ico')
Write-Output 'Generated transparent multi-resolution icons and matching PNGs.'
