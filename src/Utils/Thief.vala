// Port of https://github.com/RazrFalcon/color-thief-rs
// Main reason being matching Amberol and generally having better colors.
// Since we only need one color, the sorting is simplified and uses a formula
// for the best count / volume ratio.
public class Turntable.Utils.Thief : GLib.Object {
	const int SIGNAL_BITS = 5;
	const int RIGHT_SHIFT = 8 - SIGNAL_BITS;
	const int MULTIPLIER = 1 << RIGHT_SHIFT;
	const double MULTIPLIER_64 = (double)MULTIPLIER;
	const int HISTOGRAM_SIZE = 1 << (3 * SIGNAL_BITS);
	const int VBOX_LENGTH = 1 << SIGNAL_BITS;
	const double FRACTION_BY_POPULATION = 0.75;
	const int MAX_ITERATIONS = 1000;
	const int STEP = 5;

	public static size_t make_color_index_of (uint8 red, uint8 green, uint8 blue) {
		return (size_t)(
			((int) red << (2 * SIGNAL_BITS)) +
			((int) green << SIGNAL_BITS) +
			(int) blue
		);
	}

	protected enum ColorChannel {
		RED,
		GREEN,
		BLUE;
	}

	private class VBox : GLib.Object {
		public uint8 r_min { get; set; }
		public uint8 r_max { get; set; }
		public uint8 g_min { get; set; }
		public uint8 g_max { get; set; }
		public uint8 b_min { get; set; }
		public uint8 b_max { get; set; }
		public Gdk.RGBA average = { 0, 0, 0, 1 };
		public int volume { get; set; default = 0; }
		public int count { get; set; default = 0; }
		public float score { get; set; default = 0; }

		public VBox (uint8 r_min, uint8 r_max, uint8 g_min, uint8 g_max, uint8 b_min, uint8 b_max) {
			this.r_min = r_min;
			this.r_max = r_max;
			this.g_min = g_min;
			this.g_max = g_max;
			this.b_min = b_min;
			this.b_max = b_max;
		}

		public void recalc (int32[] histogram) {
			this.average = calc_average (histogram);
			this.count = calc_count (histogram);
			this.volume = calc_volume ();
		}

		public int calc_volume () {
			return (this.r_max - this.r_min + 1)
				* (this.g_max - this.g_min + 1)
				* (this.b_max - this.b_min + 1);
		}

		public int calc_count (int32[] histogram) {
			int count = 0;

			for (uint8 i = this.r_min; i <= this.r_max; i++) {
				for (uint8 j = this.g_min; j <= this.g_max; j++) {

					for (uint8 k = this.b_min; k <= this.b_max; k++) {
						var index = make_color_index_of (i, j, k);
						count += histogram[index];
					}
				}
			}

			return count;
		}

		public Gdk.RGBA calc_average (int32[] histogram) {
			int ntot = 0;
			int r_sum = 0;
			int g_sum = 0;
			int b_sum = 0;

			for (uint8 i = this.r_min; i <= this.r_max; i++) {
				for (uint8 j = this.g_min; j <= this.g_max; j++) {
					for (uint8 k = this.b_min; k <= this.b_max; k++) {
						size_t index = make_color_index_of (i, j, k);
						double hval = (double) histogram[index];
						ntot += (int) hval;
						r_sum += (int) (hval * ((double) i + 0.5) * MULTIPLIER_64);
						g_sum += (int) (hval * ((double) j + 0.5) * MULTIPLIER_64);
						b_sum += (int) (hval * ((double) k + 0.5) * MULTIPLIER_64);
					}
				}
			}

			if (ntot > 0) {
				int r = r_sum / ntot;
				int g = g_sum / ntot;
				int b = b_sum / ntot;
				return { r / 255f, g / 255f, b / 255f, 1 };
			} else {
				int r = MULTIPLIER * ((int) this.r_min + (int) this.r_max + 1) / 2;
				int g = MULTIPLIER * ((int) this.g_min + (int) this.g_max + 1) / 2;
				int b = MULTIPLIER * ((int) this.b_min + (int) this.b_max + 1) / 2;
				return {
					int.min (r, 255) / 255f,
					int.min (g, 255) / 255f,
					int.min (b, 255) / 255f,
					1
				};
			}
		}

		public ColorChannel widest_color_channel () {
			uint8 r_width = this.r_max - this.r_min;
			uint8 g_width = this.g_max - this.g_min;
			uint8 b_width = this.b_max - this.b_min;

			uint8 max = uint8.max (uint8.max (r_width, g_width), b_width);

			if (max == r_width) {
				return ColorChannel.RED;
			} else if (max == g_width) {
				return ColorChannel.GREEN;
			} else {
				return ColorChannel.BLUE;
			}
		}
	}

	private static inline void make_histogram_and_vbox (Gdk.Pixbuf pixbuf, out int[] histogram, out VBox vbox) {
		histogram = new int[HISTOGRAM_SIZE];

		uint8 r_min = uint8.MAX;
		uint8 r_max = uint8.MIN;
		uint8 g_min = uint8.MAX;
		uint8 g_max = uint8.MIN;
		uint8 b_min = uint8.MAX;
		uint8 b_max = uint8.MIN;

		int width = pixbuf.get_width ();
		int height = pixbuf.get_height ();
		int rowstride = pixbuf.get_rowstride ();
		int n_channels = pixbuf.get_n_channels ();

		unowned uint8[] pixels = pixbuf.get_pixels ();
		for (int y = 0; y < height; y++) {
			for (int x = 0; x < width; x += STEP) {
				int offset = y * rowstride + x * n_channels;
				uint8 r = pixels[offset];
				uint8 g = pixels[offset + 1];
				uint8 b = pixels[offset + 2];
				uint8 a = n_channels == 4 ? pixels[offset + 3] : 255;

				if (a < 125 || (r > 250 && g > 250 && b > 250)) continue;

				r = (uint8) (r >> RIGHT_SHIFT);
				g = (uint8) (g >> RIGHT_SHIFT);
				b = (uint8) (b >> RIGHT_SHIFT);

				r_min = uint8.min (r_min, r);
				r_max = uint8.max (r_max, r);
				g_min = uint8.min (g_min, g);
				g_max = uint8.max (g_max, g);
				b_min = uint8.min (b_min, b);
				b_max = uint8.max (b_max, b);

				var index = make_color_index_of (r, g, b);
				histogram[index] += 1;
			}
		}

		vbox = new VBox (r_min, r_max, g_min, g_max, b_min, b_max);
		vbox.recalc (histogram);
	}

	private static bool apply_median_cut (int[] histogram, ref VBox vbox, out VBox? vbox1, out VBox? vbox2, GLib.Cancellable cancellable) {
		vbox1 = null;
		vbox2 = null;

		if (vbox.count == 0) {
			return false;
		}

		if (vbox.count == 1) {
			vbox1 = vbox;
			return true;
		}

		int total = 0;
		int[] partial_sum = new int[VBOX_LENGTH];
		for (int i = 0; i < VBOX_LENGTH; i++) {
			partial_sum[i] = -1;
		}

		var axis = vbox.widest_color_channel ();
		switch (axis) {
			case ColorChannel.RED:
				for (uint8 i = vbox.r_min; i <= vbox.r_max; i++) {
					int sum = 0;
					for (uint8 j = vbox.g_min; j <= vbox.g_max; j++) {
						for (uint8 k = vbox.b_min; k <= vbox.b_max; k++) {
							size_t index = make_color_index_of (i, j, k);
							sum += histogram[index];
						}
					}
					total += sum;
					partial_sum[i] = total;
				}
				break;
			case ColorChannel.GREEN:
				for (uint8 i = vbox.g_min; i <= vbox.g_max; i++) {
					int sum = 0;
					for (uint8 j = vbox.r_min; j <= vbox.r_max; j++) {
						for (uint8 k = vbox.b_min; k <= vbox.b_max; k++) {
							size_t index = make_color_index_of (j, i, k);
							sum += histogram[index];
						}
					}
					total += sum;
					partial_sum[i] = total;
				}
				break;
			case ColorChannel.BLUE:
				for (uint8 i = vbox.b_min; i <= vbox.b_max; i++) {
					int sum = 0;
					for (uint8 j = vbox.r_min; j <= vbox.r_max; j++) {
						for (uint8 k = vbox.g_min; k <= vbox.g_max; k++) {
							size_t index = make_color_index_of (j, k, i);
							sum += histogram[index];
						}
					}
					total += sum;
					partial_sum[i] = total;
				}
				break;
		}

		int[] look_ahead_sum = new int[VBOX_LENGTH];
		for (int i = 0; i < VBOX_LENGTH; i++) {
			look_ahead_sum[i] = -1;
		}

		for (int i = 0; i < partial_sum.length; i++) {
			if (partial_sum[i] != -1) {
				look_ahead_sum[i] = total - partial_sum[i];
			}
		}

		if (cancellable.is_cancelled ()) return false;
		return cut (axis, ref vbox, histogram, partial_sum, look_ahead_sum, total, out vbox1, out vbox2);
	}

	private static inline bool cut (ColorChannel axis, ref VBox vbox, int[] histogram, int[] partial_sum, int[] look_ahead_sum, int total, out VBox? vbox1, out VBox? vbox2) {
		vbox1 = null;
		vbox2 = null;

		int vbox_min, vbox_max;
		switch (axis) {
			case ColorChannel.RED:
				vbox_min = vbox.r_min;
				vbox_max = vbox.r_max;
				break;
			case ColorChannel.GREEN:
				vbox_min = vbox.g_min;
				vbox_max = vbox.g_max;
				break;
			case ColorChannel.BLUE:
				vbox_min = vbox.b_min;
				vbox_max = vbox.b_max;
				break;
			default:
				assert_not_reached ();
		}

		for (int i = vbox_min; i <= vbox_max; i++) {
			if (partial_sum[i] <= total / 2) {
				continue;
			}

			vbox1 = new VBox (vbox.r_min, vbox.r_max, vbox.g_min, vbox.g_max, vbox.b_min, vbox.b_max);
			vbox2 = new VBox (vbox.r_min, vbox.r_max, vbox.g_min, vbox.g_max, vbox.b_min, vbox.b_max);

			int left = i - vbox_min;
			int right = vbox_max - i;

			int d2;
			if (left <= right) {
				d2 = int.min (vbox_max - 1, i + right / 2);
			} else {
				d2 = int.max (vbox_min, (int)((i - 1) - left / 2f));
			}

			while (d2 < 0 || partial_sum[d2] <= 0) {
				d2 += 1;
			}

			int count2 = look_ahead_sum[d2];
			while (count2 == 0 && d2 > 0 && partial_sum[d2 - 1] > 0) {
				d2 -= 1;
				count2 = look_ahead_sum[d2];
			}

			switch (axis) {
				case ColorChannel.RED:
					vbox1.r_max = (uint8)d2;
					vbox2.r_min = (uint8)(d2 + 1);
					break;
				case ColorChannel.GREEN:
					vbox1.g_max = (uint8)d2;
					vbox2.g_min = (uint8)(d2 + 1);
					break;
				case ColorChannel.BLUE:
					vbox1.b_max = (uint8)d2;
					vbox2.b_min = (uint8)(d2 + 1);
					break;
			}

			vbox1.recalc (histogram);
			vbox2.recalc (histogram);

			return true;
		}

		return false;
	}

	public static Gdk.RGBA? quantize (Gdk.Pixbuf pixbuf, int max_colors, GLib.Cancellable cancellable) {
		int[] histogram;
		VBox vbox;
		make_histogram_and_vbox (pixbuf, out histogram, out vbox);
		if (cancellable.is_cancelled ()) return null;

		var pq = new List<VBox> ();
		pq.append (vbox);
		int target = (int) Math.ceil (FRACTION_BY_POPULATION * max_colors);
		iterate (ref pq, (CompareFunc<VBox>) compare_by_count, target, histogram, cancellable);
		if (cancellable.is_cancelled ()) return null;

		int max_count = 0;
		int max_volume = 0;
		foreach (var p_vbox in pq) {
			max_count = int.max (max_count, p_vbox.count);
			max_volume = int.max (max_volume, p_vbox.volume);
		}

		foreach (var p_vbox in pq) {
			p_vbox.score = 0.3f * p_vbox.count / max_count + 0.7f * p_vbox.volume / max_volume;
		}

		pq.sort (((CompareFunc<VBox>) compare_by_score));
		if (pq.length () > 0) {
			return pq.first ().data.average;
		}

		return null;
	}

	private static void iterate (ref List<VBox> queue, CompareFunc<VBox> comparator, int target, int[] histogram, GLib.Cancellable cancellable) {
		int color = 1;

		for (int i = 0; i < MAX_ITERATIONS; i++) {
			if (queue.is_empty ()) {
				continue;
			}

			var vbox = queue.last ().data;
			if (vbox.count == 0) {
				queue.sort (comparator);
				continue;
			}
			queue.remove (queue.last ().data);

			VBox? vbox1 = null;
			VBox? vbox2 = null;
			if (cancellable.is_cancelled ()) break;
			if (!apply_median_cut (histogram, ref vbox, out vbox1, out vbox2, cancellable)) {
				continue;
			}

			queue.append (vbox1);
			if (vbox2 != null) {
				queue.append (vbox2);
				color++;
			}

			queue.sort (comparator);

			if (color >= target) {
				break;
			}
		}
	}

	private static int compare_by_count (VBox a, VBox b) {
		return a.count - b.count;
	}

	private static int compare_by_score (VBox a, VBox b) {
		if (a.score == b.score) {
			return 0;
		} else if (a.score > b.score) {
			return -1;
		} else {
			return 1;
		}
	}
}
