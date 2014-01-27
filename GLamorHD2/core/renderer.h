//
//  renderer.h
//  GLamor
//
//  Created by Ge Wang on 1/21/14.
//  Copyright (c) 2014 Ge Wang. All rights reserved.
//

#ifndef __GLamor__renderer__
#define __GLamor__renderer__


// initialize the engine (audio, grx, interaction)
void GLamorInit();
// TODO: cleanup
// set graphics dimensions
void GLamorSetDims( GLfloat width, GLfloat height );
// draw next frame of graphics
void GLamorRender();



#endif /* defined(__GLamor__renderer__) */
