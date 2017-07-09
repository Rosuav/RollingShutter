//Render the entire animation, one row at a time

int width = 200, height = 150; //Default image dimensions (small for fast test renders)
int threads = 64;
array image_data;
constant rotation = 300.0; //The prop rotates this many degrees (must be float) during the rendering
string header;
array animation = ({0});
array progressive; //Only allocated in progressive mode
string filename;

int started = time();

//No animation at all. Will render one still frame.
float _clock_null(int pos, int y) {return rotation * y / height;}
constant desc_rotate = "Rotate the prop slowly one half turn during animation";
float clock_rotate(int pos, int y) {return rotation * y / height + 180.0 * pos / sizeof(animation);}
constant desc_accelerate = "Adjust the prop's speed (it'll start stationary and accelerate)";
float clock_accelerate(int pos, int y) {return (rotation * pos / sizeof(animation) * 2) * y / height;}

function calculate_clock = _clock_null;

//Take a string of PPM data (assumed 16-bit - TODO: support 8-bit too) and
//dim it by multiplying every value by the given factor.
string dim(string data, float factor)
{
	sscanf(data, "%{%2c%}", array values);
	values = values * ({ }); //Flatten out sscanf's layering
	if (factor == 0.5) values = values[*] / 2; //Fast path for halving
	else values = values[*] * factor; //Do the dimming
	return sprintf("%@2c", (array(int))values); //And turn it back into a string. fxnUp
}

mapping cheat;
void renderer(Thread.Queue rows, Thread.Queue results, int pos)
{
	while (1)
	{
		int y = rows->try_read();
		if (undefinedp(y)) break;
		mapping rc = cheat || Process.run(({"povray", "-d", "propeller.pov",
			"+W"+width, "+H"+height, "+SR"+y, progressive ? "" : "+ER"+(y+1),
			"+K" + calculate_clock(pos, y),
			"+O-", "+FP16",
		}));
		//cheat = rc; //Uncomment to nerf the actual rendering and use the same frame for everything
		if (rc->exitcode) exit(rc->exitcode, rc->stderr);
		//Decode PPM data from rc->stdout
		sscanf(rc->stdout, "P6%s", string ppm);
		array info = ({0,0,0}); //width, height, bitdepth
		for (int token = 0; token < 3; ++token)
		{
			sscanf(ppm, "%*[ \t\n]%s", ppm); //Ignore whitespace
			while (sscanf(ppm, "#%*[^\n]\n%s", ppm)) ; //Ignore comments
			sscanf(ppm, "%d%s", info[token], ppm);
		}
		//assert ppm[0] is whitespace
		ppm = ppm[1..];
		if (!header) header = rc->stdout[..<sizeof(ppm)];
		int line_bytes = info[0] * 3; //Red, Green, and Blue samples for each pixel
		if (info[2] > 255) line_bytes *= 2;
		array lines = ppm / line_bytes;
		image_data[y] = lines[y];
		if (progressive) progressive[y] = lines;
		results->write(({y, this_thread()}));
	}
	results->write(({-1, this_thread()}));
}

void render_frame(int pos)
{
	int frametime = time();
	Thread.Queue results = Thread.Queue();
	Thread.Queue rows = Thread.Queue();
	rows->write(Array.shuffle(enumerate(height))[*]);
	int threads_left;
	for (threads_left = 0; threads_left < threads; ++threads_left)
	{
		Thread.Thread(renderer, rows, results, pos);
		//sleep(0.1); //Stagger them a bit
	}
	int done = 0;
	int lastclock = 0;
	while (threads_left)
	{
		[int y, object cur] = results->read();
		if (y == -1) {--threads_left; continue;}
		write("[%d] %d/%d...\r", pos, ++done, height);
		if (!filename)
		{
			//Don't need partial frame rendering when animating
			if (lastclock != time(1))
			{
				lastclock = time(1);
				Process.run(({"ffmpeg", "-y", "-i", "-", "prop.png"}),
					(["stdin": header + image_data * ""]));
			}
		}
	}
	int finish = time() + (time() - started) * (sizeof(animation) - pos - 1) / (pos + 1);
	write("[%d] %d/%d - done in %ds, est finish %s", pos, done, height,
		time() - frametime, ctime(finish));
	if (!filename)
	{
		//Render a single frame as a PNG. No animation.
		Process.run(({"ffmpeg", "-y", "-i", "-", "prop.png"}),
			(["stdin": header + image_data * ""]));
		return;
	}
	animation[pos] = header + image_data * "";
	Process.run(({"ffmpeg", "-y", "-f", "image2pipe", "-i", "-", filename + ".gif"}),
		(["stdin": animation * ""]));
}

int main(int argc, array(string) argv)
{
	foreach (argv[1..], string arg)
	{
		if (arg == "list")
		{
			write("Available animation functions\n");
			write("progressive - Demonstrate the effect via a progressive render of one frame\n");
			foreach (sort(indices(this)), string key) if (sscanf(key, "clock_%s", string f))
				write("%s - %s\n", f, this["desc_" + f]);
			return 0;
		}
		if (arg == "progressive")
		{
			//Animate the progressive renderer
			filename = arg; //And the devicatMAGIC happens
			rm("anim.gif"); symlink(filename + ".gif", "anim.gif");
		}
		else if (function f = this["clock_" + arg])
		{
			//Select an animation function and it also sets the file name.
			filename = arg;
			calculate_clock = f;
			rm("anim.gif"); symlink(filename + ".gif", "anim.gif");
			animation = animation || allocate(8); //Default frame count (low for fast test renders)
		}
		else if (sscanf(arg, "%dx%dx%d", int w, int h, int frm) && frm)
		{
			width = w; height = h;
			animation = allocate(frm);
		}
		else if (sscanf(arg, "%dx%d", int w, int h) && w && h)
		{
			//Leave the animation frame count at the default (maybe none)
			width = w; height = h;
		}
		else if (sscanf(arg, "-j%d", int t) && t)
		{
			//Set parallelism. For huge renders, one thread per core is about right;
			//for small renders, crank it up, and for tiny ones, crank it way up.
			//For 800x600, -j32 seems good; for 200x150, even -j100.
			threads = t;
		}
		else if (arg == "grind")
		{
			string data = random_string(7200);
			write("Generated %d bytes of random data\n", sizeof(data));
			float tm = gauge {for (int i=0; i<10000; ++i) dim(data, 0.5);};
			write("Dimmed in %fs\n", tm);
			return 0;
		}
	}
	image_data = allocate(height, "\0" * (width * 3 * 2));
	if (filename == "progressive")
	{
		progressive = allocate(height);
	}
	foreach (animation; int pos;) render_frame(pos);
	if (progressive)
	{
		//Render each frame as:
		//1) Lines up to the current one at 0.75 brightness (maybe)
		//2) The current line at 1.0 brightness
		//3) The rest of the image from the current image's data, at 0.5 brightness
		//Note that the internal animation loop is not used in this mode.

		Stdio.File ffmpeg = Stdio.File();
		Process.Process proc = Process.Process(
			({"ffmpeg", "-y", "-f", "image2pipe", "-i", "-", filename + ".gif"}),
			([/*"stdout": Stdio.File("/dev/null")->pipe(),
			"stderr": Stdio.File("/dev/null")->pipe(),*/
			"stdin": ffmpeg->pipe(Stdio.PROP_IPC|Stdio.PROP_REVERSE)])
		);
		//animation = allocate(height);
		//Since the intermediate 'progressive' array won't be needed after this, we
		//reuse it for the output frames. This effectively means that we discard the
		//intermediate data as soon as we're done preparing that frame, and reduces
		//memory usage notably: 2213416 with reuse, 2855796 w/o.
		animation = progressive;
		string past = ""; //Lines "in the past". Gets the current row added _after_ rendering.
		array frame;
		for (int frm = 0; frm < height; ++frm)
		{
			write("[1] %d/%d...\r", frm, height);
			frame = ({
				header,
				//Lines in the past
				past,
				//Current line
				image_data[frm],
				//Lines in the future
			}) +	dim(progressive[frm][frm + 1..][*], 0.5);
			progressive[frm] = 0; //Discard data we don't need any more
			ffmpeg->write(frame * "");
			//past += dim(image_data[frm], 0.75); //Dim the past
			past += image_data[frm]; //Keep past fully bright
		}
		write("[1] %d/%<d - done\n", height);
		//Duplicate the last frame a few times to create a bit of a pause
		ffmpeg->write(frame * "" * 31);
		ffmpeg->close();
		proc->wait();
		write("Render complete.\n");
	}
}
