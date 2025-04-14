public class Turntable.Utils.Color {
	public struct ExtractedColors {
		public Gdk.RGBA? light;
		public Gdk.RGBA? dark;
	}

	public static Gdk.RGBA get_average_color (Gdk.Pixbuf pixbuf, Cancellable cancellable) {
		int width = pixbuf.get_width ();
		int height = pixbuf.get_height ();
		int rowstride = pixbuf.get_rowstride ();
		int n_channels = pixbuf.get_n_channels ();
		unowned uint8[] pixels = pixbuf.get_pixels ();

		ulong sum_r = 0, sum_g = 0, sum_b = 0;
		int total_pixels = width * height;

		for (int y = 0; y < height; y++) {
			for (int x = 0; x < width; x++) {
				int offset = y * rowstride + x * n_channels;
				sum_r += pixels[offset];
				sum_g += pixels[offset + 1];
				sum_b += pixels[offset + 2];
			}
		}

		Gdk.RGBA avg_color = Gdk.RGBA () {
			red = (float) (sum_r / total_pixels / 255.0),
			green = (float) (sum_g / total_pixels / 255.0),
			blue = (float) (sum_b / total_pixels / 255.0),
			alpha = 1.0f
		};

		return avg_color;
	}

	public static ExtractedColors get_contrasting_colors (Gdk.RGBA color) {
		ExtractedColors result = { color, color };
		double luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue;

		if (luminance > 0.85) {
			result.light = Gdk.RGBA () {
				red = color.red * 0.7f,
				green = color.green * 0.7f,
				blue = color.blue * 0.7f,
				alpha = 1f
			};

			if (luminance > 0.9) {
				result.dark = Gdk.RGBA () {
					red = color.red * 0.5f,
					green = color.green * 0.5f,
					blue = color.blue * 0.5f,
					alpha = 1f
				};
			}
		} else if (luminance < 0.25) {
			result.dark = Gdk.RGBA () {
				red = color.red + (1.0f - color.red) * 0.7f,
				green = color.green + (1.0f - color.green) * 0.7f,
				blue = color.blue + (1.0f - color.blue) * 0.7f,
				alpha = 1f
			};

			if (luminance < 0.15) {
				result.light = Gdk.RGBA () {
					red = color.red + (1.0f - color.red) * 0.25f,
					green = color.green + (1.0f - color.green) * 0.25f,
					blue = color.blue + (1.0f - color.blue) * 0.25f,
					alpha = 1f
				};
			}
		}

		return result;
	}
}
