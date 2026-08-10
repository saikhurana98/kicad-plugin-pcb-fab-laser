import os
import pcbnew
import wx

from .exporter import LaserExporter, ExportOptions


class PcbFabLaserPlugin(pcbnew.ActionPlugin):
    def defaults(self):
        self.name = "PCB Fab Laser SVG Export"
        self.category = "Fabrication"
        self.description = (
            "Export SVG layers (B.Cu negative, B.SilkS, Edge.Cuts) "
            "for xTool laser PCB fabrication."
        )
        self.show_toolbar_button = True
        self.icon_file_name = os.path.join(os.path.dirname(__file__), "icon.png")

    def Run(self):
        board = pcbnew.GetBoard()
        if board is None:
            wx.MessageBox("No board loaded.", "PCB Fab Laser", wx.OK | wx.ICON_ERROR)
            return

        dlg = ExportDialog(None, board)
        try:
            dlg.ShowModal()
        finally:
            dlg.Destroy()


class ExportDialog(wx.Dialog):
    def __init__(self, parent, board):
        super().__init__(parent, title="PCB Fab Laser SVG Export", size=(500, 470))
        self.board = board

        panel = wx.Panel(self)
        sizer = wx.BoxSizer(wx.VERTICAL)

        sizer.Add(wx.StaticText(panel, label="Layers to include in ablate.svg:"),
                  flag=wx.ALL, border=8)
        self.cb_bcu = wx.CheckBox(panel, label="B.Cu (copper, negative — keep traces)")
        self.cb_silk = wx.CheckBox(panel, label="B.SilkS (silkscreen, positive)")
        self.cb_bcu.SetValue(True)
        self.cb_silk.SetValue(True)
        sizer.Add(self.cb_bcu, flag=wx.LEFT | wx.RIGHT, border=16)
        sizer.Add(self.cb_silk, flag=wx.LEFT | wx.RIGHT | wx.BOTTOM, border=16)

        sizer.Add(wx.StaticLine(panel), flag=wx.EXPAND | wx.ALL, border=4)

        sizer.Add(wx.StaticText(panel, label="Separate files:"),
                  flag=wx.ALL, border=8)
        self.cb_edge = wx.CheckBox(panel, label="Edge.Cuts (board outline → cut.svg)")
        self.cb_edge.SetValue(True)
        sizer.Add(self.cb_edge, flag=wx.LEFT | wx.RIGHT, border=16)
        self.cb_drill = wx.CheckBox(panel, label="Drill holes (vias + pad drills → drill.svg)")
        self.cb_drill.SetValue(True)
        sizer.Add(self.cb_drill, flag=wx.LEFT | wx.RIGHT | wx.BOTTOM, border=16)

        sizer.Add(wx.StaticLine(panel), flag=wx.EXPAND | wx.ALL, border=4)

        self.cb_mirror = wx.CheckBox(panel, label="Mirror (bottom-side laser)")
        self.cb_mirror.SetValue(True)
        sizer.Add(self.cb_mirror, flag=wx.ALL, border=8)

        png_box = wx.BoxSizer(wx.HORIZONTAL)
        self.cb_png = wx.CheckBox(panel, label="Also rasterize PNG @ DPI:")
        self.cb_png.SetValue(True)
        png_box.Add(self.cb_png, flag=wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, border=8)
        self.txt_dpi = wx.TextCtrl(panel, value="1000", size=(70, -1))
        png_box.Add(self.txt_dpi, flag=wx.ALIGN_CENTER_VERTICAL)
        sizer.Add(png_box, flag=wx.LEFT | wx.RIGHT | wx.BOTTOM, border=8)

        out_box = wx.BoxSizer(wx.HORIZONTAL)
        out_box.Add(wx.StaticText(panel, label="Output dir:"),
                    flag=wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, border=8)
        project_dir = os.path.dirname(board.GetFileName()) or os.path.expanduser("~")
        default_dir = os.path.join(project_dir, "export_artifacts")
        self.txt_outdir = wx.TextCtrl(panel, value=default_dir)
        out_box.Add(self.txt_outdir, proportion=1, flag=wx.EXPAND | wx.RIGHT, border=4)
        btn_browse = wx.Button(panel, label="...")
        btn_browse.Bind(wx.EVT_BUTTON, self.on_browse)
        out_box.Add(btn_browse)
        sizer.Add(out_box, flag=wx.EXPAND | wx.ALL, border=8)

        btn_box = wx.BoxSizer(wx.HORIZONTAL)
        btn_export = wx.Button(panel, label="Export")
        btn_export.Bind(wx.EVT_BUTTON, self.on_export)
        btn_cancel = wx.Button(panel, id=wx.ID_CANCEL, label="Cancel")
        btn_box.AddStretchSpacer()
        btn_box.Add(btn_export, flag=wx.RIGHT, border=8)
        btn_box.Add(btn_cancel)
        sizer.Add(btn_box, flag=wx.EXPAND | wx.ALL, border=8)

        panel.SetSizer(sizer)

    def on_browse(self, _evt):
        dlg = wx.DirDialog(self, "Choose output directory",
                           defaultPath=self.txt_outdir.GetValue())
        if dlg.ShowModal() == wx.ID_OK:
            self.txt_outdir.SetValue(dlg.GetPath())
        dlg.Destroy()

    def on_export(self, _evt):
        outdir = self.txt_outdir.GetValue().strip()
        if not outdir:
            wx.MessageBox("Output directory empty.", "Error",
                          wx.OK | wx.ICON_ERROR)
            return
        try:
            os.makedirs(outdir, exist_ok=True)
        except OSError as e:
            wx.MessageBox(f"Cannot create {outdir}:\n{e}", "Error",
                          wx.OK | wx.ICON_ERROR)
            return

        try:
            dpi = int(self.txt_dpi.GetValue())
            if dpi <= 0:
                raise ValueError
        except ValueError:
            wx.MessageBox("DPI must be positive integer.", "Error",
                          wx.OK | wx.ICON_ERROR)
            return

        opts = ExportOptions(
            include_bcu=self.cb_bcu.GetValue(),
            include_silk=self.cb_silk.GetValue(),
            include_edge=self.cb_edge.GetValue(),
            include_drill=self.cb_drill.GetValue(),
            mirror=self.cb_mirror.GetValue(),
            rasterize_png=self.cb_png.GetValue(),
            dpi=dpi,
            outdir=outdir,
        )

        try:
            exporter = LaserExporter(self.board, opts)
            written = exporter.run()
        except Exception as e:
            wx.MessageBox(f"Export failed:\n{e}", "Error",
                          wx.OK | wx.ICON_ERROR)
            return

        wx.MessageBox(
            "Exported:\n" + "\n".join(written) if written else "Nothing exported.",
            "PCB Fab Laser",
            wx.OK | wx.ICON_INFORMATION,
        )
        self.EndModal(wx.ID_OK)
