//Render the entire animation, one row at a time

constant width = 800, height = 600;

int main()
{
	Image.Image result = Image.Image(width, height);
	for (int y = 0; y < height; ++y)
	{
		write("%d/%d...\r", y, height);
		mapping rc = Process.run(({"povray", "-d", "propeller.pov",
			"+W"+width, "+H"+height, "+SR"+y, "+ER"+(y+1),
			"+K"+(100.0*y/height), //Clock runs in percentages
			"+O-",
		}));
		if (rc->exitcode) exit(rc->exitcode, rc->stderr);
		Image.Image cur = Image.PNG.decode(rc->stdout);
		result->paste(cur->copy(0, y, width, y+1), 0, y);
		Stdio.write_file("prop.png", Image.PNG.encode(result));
	}
	write("%d/%<d - done\n", height);
}
