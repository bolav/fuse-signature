using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Uno.Graphics;
using Uno.IO;
using Fuse;
using Fuse.Input;
using Fuse.Scripting;

using OpenGL;

public class Signature : Fuse.Controls.Panel
{
    protected override void OnRooted()
    {
        base.OnRooted();
		Pointer.Pressed.AddHandler(this, OnPointerPressed);
		Pointer.Moved.AddHandler(this, OnPointerMoved);
		Pointer.Released.AddHandler(this, OnPointerReleased);
    }

    protected override void OnUnrooted()
    {
		Pointer.Pressed.RemoveHandler(this, OnPointerPressed);
		Pointer.Moved.RemoveHandler(this, OnPointerMoved);
		Pointer.Released.RemoveHandler(this, OnPointerReleased);
        base.OnUnrooted();
    }

	bool _isDrawing = false;
	int _pressedPointIndex = -1;

	void OnLostCapture()
	{
		debug_log "OnLostCapture";
		_isDrawing = false;
		_pressedPointIndex = -1;
	}

    float2 _lp;
    List<float2> _lines = new List<float2>();
    int _vertcount;

    float2[] _verts = new float2[]
    {
        float2(-0.5f, -0.5f),
        float2( 0.5f, -0.5f)
    };

    float4 _color = float4(0.9f, 0.1f, 0.1f, 1);
    public float4 DrawColor {
		get { return _color; }
		set { _color = value; }
    }

    float _width = 4f;
    public float StrokeWidth {
		get { return _width; }
		set { _width = value; }
    }

    public float2 ViewActualPosition {
    	get {
    		var pos = ActualPosition;
    		var vis = Parent;
    		while (vis != null) {
    			var el = vis as Fuse.Elements.Element;
    			if (el != null) {
    				pos += el.ActualPosition;
    			}
    			vis = vis.Parent;
    		}
    		return pos;
    	}
    }

    float2 ConvertPoint(float2 p, float2 size) {
		p = p / size;
		p = (p * float2(2,-2)) - float2(1,-1);
		return p;
    }

	void OnPointerPressed(object sender, PointerPressedArgs c)
	{
		_isDrawing = true;
		_pressedPointIndex = c.PointIndex;

		if (Focus.IsWithin(this))
			c.TryHardCapture(this, OnLostCapture);
		else
			c.TrySoftCapture(this, OnLostCapture);

        _lp = c.WindowPoint - ViewActualPosition;
        InvalidateVisual();
	}

	void OnPointerMoved(object sender, PointerMovedArgs c)
	{
		if (_pressedPointIndex != c.PointIndex)
			return;

		// _center = WindowToLocal(c.WindowPoint);
		_lines.Add(_lp);
		_lp = c.WindowPoint - ViewActualPosition;
		_lines.Add(_lp);
		InvalidateVisual();

		if (c.IsHardCapturedTo(this))
		{
			c.IsHandled = true;
		}
	}

	void OnPointerReleased(object sender, PointerReleasedArgs c)
	{
		if (_pressedPointIndex != c.PointIndex)
			return;

		if (c.IsHardCapturedTo(this))
		{
			c.ReleaseCapture(this);
			c.IsHandled = true;
		}
		else if (c.IsSoftCapturedTo(this))
		{
			c.ReleaseCapture(this);
		}
		_pressedPointIndex = -1;
		_isDrawing = false;
	}

	void CreateVerts(float2 size, float2 pos) {
		_verts = _lines.ToArray();
		for (var i = 0; i < _lines.Count; i++) {
			_verts[i] = ConvertPoint(_verts[i] + pos, size);
		}
		_vertcount = _lines.Count;
	}

    protected override void DrawVisual(DrawContext dc)
    {
        float2 pos = dc.Scissor.Position;
        CreateVerts(dc.GLViewportPointSize,  pos / dc.ViewportPixelsPerPoint);

        draw Fuse.Drawing.Planar.Rectangle
        {
            DrawContext: dc;
            Visual: this;

            VertexCount: _lines.Count;
            ClipPosition: float4(vertex_attrib(_verts), 0, 1);
            PixelColor: _color;
            LineWidth : _width;
            PrimitiveType: Uno.Graphics.PrimitiveType.Lines;
        };
    }

    protected override VisualBounds HitTestLocalVisualBounds
    {
        get
        {
            var nb = base.HitTestLocalVisualBounds;
            nb = nb.AddRect( float2(0), ActualSize );
            return nb;
        }
    }

    protected override void OnHitTestLocalVisual(HitTestContext htc)
    {
        if (IsPointInside(htc.LocalPoint))
            htc.Hit(this);

        base.OnHitTestLocalVisual(htc);
    }

    protected override VisualBounds CalcRenderBounds()
    {
        var b = base.CalcRenderBounds();
        b = b.AddRect( float2(0), ActualSize );
        return b;
    }


}
