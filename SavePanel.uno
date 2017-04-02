using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Uno.Graphics;
using Uno.IO;
using Fuse;
using Fuse.Input;
using Fuse.Scripting;

using OpenGL;

[ForeignInclude(Language.ObjC, "OpenGLES/ES2/glext.h")]
[Require("Source.Include", "uBase/Buffer.h")]
[Require("Source.Include", "uImage/Bitmap.h")]
[Require("Source.Include", "uImage/Png.h")]
[Require("Source.Include", "uBase/Memory.h")]

public class SavePanel : Fuse.Controls.Panel
{
	static SavePanel()
	{
		ScriptClass.Register(typeof(SavePanel),
			new ScriptMethod<SavePanel>("save", Save, ExecutionThread.MainThread));
	}

	static void Save(Context c, SavePanel s, object [] args) {
		if (args.Length != 1)
		{
			Fuse.Diagnostics.UserError( "SavePanel.save requires 1 parameter (filename)", s );
			return;
		}

		s.Save(args[0].ToString());
	}

	string _savefn;
	public void Save(string filename) {
		_savefn = Path.Combine(Directory.GetUserDirectory(UserDirectory.Data), filename);
		debug_log "Saving to " + _savefn;

		_captureNextFrame = true;
		InvalidateVisual();
	}

	bool _captureNextFrame;

	bool TryGetCaptureRect(out Recti rect)
	{
		var bounds = RenderBoundsWithEffects;
		if (bounds.IsInfinite || bounds.IsEmpty)
		{
			rect = new Recti(0,0,0,0);
			return false;
		}

		var scaled = Rect.Scale(bounds.FlatRect, AbsoluteZoom);
		int2 origin = (int2)Math.Floor(scaled.LeftTop);
		int2 size = (int2)Math.Ceil(scaled.Size);
		rect = new Recti(origin.X, origin.Y, origin.X + size.X, origin.Y + size.Y);
		return true;
	}

	float2 _lastsize = float2(0);
	protected override void DrawWithChildren(DrawContext dc)
	{
		if (_captureNextFrame)
		{
			Recti rect;
			if (!TryGetCaptureRect(out rect))
			{
				debug_log "failed to get capture-rectangle, falling back to scissor-box";
				rect = dc.Scissor;
			}

			var size = rect.Size;

			var fb = new framebuffer(size, Format.RGBA8888, FramebufferFlags.None);
			var cc = new OrthographicFrustum
			{
				Origin = float2(rect.Minimum.X, rect.Minimum.Y) / AbsoluteZoom,
				Size = float2(size.X, size.Y) / AbsoluteZoom,
				LocalFromWorld = WorldTransformInverse
			};

			dc.PushRenderTargetFrustum(fb, cc);

			dc.Clear(float4(0));
			dc.Clear(float4(0.5f, 0, 0.5f, 0.5f));
			base.DrawWithChildren(dc);

			var buffer = new byte[size.X * size.Y * 4];
			GL.PixelStore(GLPixelStoreParameter.PackAlignment, 1);
			GL.ReadPixels(0, 0, size.X, size.Y, GLPixelFormat.Rgba, GLPixelType.UnsignedByte, buffer);

			dc.PopRenderTargetFrustum();

			SavePng(buffer, size.X, size.Y, _savefn);

			fb.Dispose();
			_captureNextFrame = false;

		}

		base.DrawWithChildren(dc);
	}

	extern(!CPlusPlus) public void SavePng(byte[] data, int w, int h, string path) {
		Fuse.Diagnostics.UserError( "SavePanel.save not working in local preview yet", this );
		return;
	}
	extern(CPlusPlus) public void SavePng(byte[] data, int w, int h, string path)
	@{
/*		try
		{ */
			uBase::Buffer *buf = uBase::Buffer::CopyFrom(data, w * h * 4);

			uImage::Bitmap *bmp = new uImage::Bitmap(w, h, uImage::FormatRGBA_8_8_8_8_UInt_Normalize);
			int pitch = w * 4;
			// OpenGL stores the bottom scan-line first, PNG stores it last. Flip image while copying to compensate.
			for (int y = 0; y < h; ++y) {
				uint8_t *src = ((uint8_t*)data->Ptr()) + y * pitch;
				uint8_t *dst = bmp->GetScanlinePtr(h - y - 1);
				memcpy(dst, src, pitch);
			}

			uImage::Png::Save(uStringToXliString(path), bmp);
			delete bmp;
/*		}
		catch (const uBase::Exception &e)
		{
			U_THROW(@{Uno.Exception(string):New(uStringFromXliString(e.GetMessage()))});
		} */
	@}

}
