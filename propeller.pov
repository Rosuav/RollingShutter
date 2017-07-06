#include "shapes.inc"
#include "colors.inc"
#include "textures.inc"
#include "metals.inc"

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

//Propeller blade from http://www.f-lohmueller.de/pov_tut/x_sam/tec_851e.htm

#declare Rotation_Angle = clock; //Give full control to the external animation loop
// ------------------------------------ dimensions of the blades
#declare Number_of_Blades = 2;
#declare Blade_Radius  = 3.00; // length of the propeller blades
// --------------------------------------- texture of the blades
#declare Blades_Texture =
 texture { Chrome_Metal finish{ambient 0.1 diffuse 0.8 phong 1}}
// -------------------------------------------------------------
union{  // propeller -------------------------------------------
   cylinder  { <0,0,-0.01>,<0,0,1.00>,0.10 }  // propeller axis
   difference{                                 // propeller nose
               sphere{<0,0,0>, 1}
               box {<-1,-1,-0.1>,<1,1,1>}
               scale <1,1,2.5>*0.3
               translate<0,0,0.2>
             }
   union{  // blades
     #declare Nr = 0;
     #declare End = Number_of_Blades;
     #while (  Nr < End)
        sphere { < 0, 0, 0>,0.5
                 translate <0.5,0,0>
                 scale <1,0.15,0.04> rotate <10,0,0>
                 scale Blade_Radius
                 texture {Blades_Texture}
                 rotate< 0,0, 360/End * Nr >
               }
     #declare Nr = Nr + 1;
     #end
   } // end of union of the blades
   texture{Blades_Texture}
   translate <0,0,-0.5>
   rotate <0,0,Rotation_Angle>
} // end of union propeller  ------------------------------------

// --------- end from http://www.f-lohmueller.de/pov_tut/x_sam/tec_851e.htm
