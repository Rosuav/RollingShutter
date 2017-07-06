//Render the entire animation, one row at a time

constant width = 400, height = 300;
constant threads = 4;

void renderer(Thread.Queue rows, Thread.Queue results)
{
	while (1)
	{
		int y = rows->try_read();
		if (undefinedp(y)) break;
		mapping rc = Process.run(({"povray", "-d", "propeller.pov",
			"+W"+width, "+H"+height, "+SR"+y, "+ER"+(y+1),
			"+K"+(100.0*y/height), //Clock runs in percentages
			"+O-",
		}));
		if (rc->exitcode) exit(rc->exitcode, rc->stderr);
		Image.Image cur = Image.PNG.decode(rc->stdout);
		results->write(({y, cur->copy(0, y, width, y)}));
	}
	results->write(({-1, this_thread()}));
}

int main()
{
	Image.Image result = Image.Image(width, height);
	Thread.Queue results = Thread.Queue();
	Thread.Queue rows = Thread.Queue();
	rows->write(enumerate(height)[*]);
	int threads_left;
	for (threads_left = 0; threads_left < threads; ++threads_left)
	{
		Thread.Thread(renderer, rows, results);
		sleep(0.1); //Stagger them a bit
	}
	int done = 0;
	while (threads_left)
	{
		[int y, Image.Image cur] = results->read();
		if (y == -1) {--threads_left; continue;}
		result->paste(cur, 0, y);
		Stdio.write_file("prop.png", Image.PNG.encode(result));
		write("%d/%d...\r", ++done, height);
	}
	write("%d/%d - done\n", done, height);
}
