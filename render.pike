//Render the entire animation, one row at a time

constant width = 400, height = 300;
constant threads = 100;
constant image_data = allocate(height, "\0" * (width * 3 * 2));
constant rotation = 300.0; //The prop rotates this many degrees (must be float) during the rendering
string header;
constant animation = allocate(32); //Animation frame count

void renderer(Thread.Queue rows, Thread.Queue results, int pos)
{
	while (1)
	{
		int y = rows->try_read();
		if (undefinedp(y)) break;
		mapping rc = Process.run(({"povray", "-d", "propeller.pov",
			"+W"+width, "+H"+height, "+SR"+y, "+ER"+(y+1),
			//This rotates the prop slowly one full turn during animation
			"+K" + (rotation * y / height + 360.0 / sizeof(animation) * pos),
			"+O-", "+FP16",
		}));
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
		results->write(({y, this_thread()}));
	}
	results->write(({-1, this_thread()}));
}

void render_frame(int pos)
{
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
		if (lastclock != time(1))
		{
			lastclock = time(1);
			Process.run(({"ffmpeg", "-y", "-i", "-", "prop.png"}),
				(["stdin": header + image_data * ""]));
		}
	}
	write("[%d] %d/%d - done\n", pos, done, height);
	animation[pos] = header + image_data * "";
	Process.run(({"ffmpeg", "-y", "-f", "image2pipe", "-i", "-", "anim.gif"}),
		(["stdin": animation * ""]));
}

int main()
{
	foreach (animation; int pos;) render_frame(pos);
}
