#include "colors.inc"

#version 3.7;

global_settings {
	assumed_gamma 2.2
}

camera {
	location <0.0, 0.0, -10.0>
	look_at 0
}

light_source { <0.0, 40.0, -30.0> colour White }

//floor
plane {
	y, -8
	texture {pigment {
		checker colour <1.0, 0.0, 0.0>
		colour <0.0, 0.8, 1.0>
		scale 5
	} }
}

//backdrop
plane {
	z, 50
	texture {pigment {colour <0.7, 1.0, 0.7>} }
}
