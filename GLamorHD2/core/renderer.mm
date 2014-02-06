//
//  renderer.cpp
//  GLamor
//
//  Created by Ge Wang on 1/21/14.
//  Copyright (c) 2014 Ge Wang. All rights reserved.
//
#import "renderer.h"
#import "mo_audio.h"
#import "mo_gfx.h"
#import "mo_touch.h"
#import "mo_accel.h"
#import "Mandolin.h"
#import "Shakers.h"
#import <vector>
#import "ShotGlobals.h"

using namespace std;


#define SRATE 24000
#define FRAMESIZE 512
#define NUM_CHANNELS 2
#define NUM_ENTITIES 200

// global variables
GLfloat g_waveformWidth = 2;
//GLfloat g_gfxWidth = 1024;
GLfloat g_gfxWidth = 960;
GLfloat g_gfxHeight = 640;
GLfloat g_ratio = g_gfxWidth/g_gfxHeight;
stk::Mandolin *g_mandolin;
stk::Shakers *g_colliding_sound;
stk::Shakers *g_wall_sound;

// buffer
SAMPLE g_vertices[FRAMESIZE*2];
UInt32 g_numFrames;

// texture
GLuint g_texture[2];



static const GLfloat squareVertices[] = {
    -0.5f,  -0.5f,
    0.5f,  -0.5f,
    -0.5f,   0.5f,
    0.5f,   0.5f,
};

static const GLfloat normals[] = {
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    0, 0, 1
};

static const GLfloat texCoords[] = {
    0, 1,
    1, 1,
    0, 0,
    1, 0
};

class Entity
{
public:
    // constructor
    Entity() {
        alpha = 1.0;
        active = false;
    }
    
    // update
    virtual void update( double dt )
    { }
    // redner
    virtual void render()
    { }

public:
    Vector3D loc;
    Vector3D ori;
    Vector3D sca;
    Vector3D col;
    GLfloat alpha;
    GLboolean active;

};

class TextureObject : public Entity{
public:
    TextureObject(GLuint texture){
        m_texture = texture;
        
    }
    
    virtual void render(){
        // enable texture mapping
        glEnable( GL_TEXTURE_2D );
        // enable blending
        glEnable( GL_BLEND );
        // set blend func
        glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
        // glBlendFunc( GL_ONE, GL_ONE );
        
        // bind the texture
        glBindTexture( GL_TEXTURE_2D, m_texture );
        
        // vertex
        glVertexPointer( 2, GL_FLOAT, 0, squareVertices );
        glEnableClientState(GL_VERTEX_ARRAY );
        
        // texture coordinate
        glTexCoordPointer( 2, GL_FLOAT, 0, texCoords );
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );
        
        // triangle strip
        glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 );
        
        // disable blend
        glDisable( GL_BLEND );
        glDisable( GL_TEXTURE_2D );
        
    }
public:
    GLuint m_texture;
};

class TouchObject : public TextureObject{

public:
    TouchObject(GLuint texture, BOOL pulsating) : TextureObject(texture){
        
        this->m_pulsating = pulsating;
        this->m_increasing = YES;
        

        
        
    }
    // update
    virtual void update( double dt )
    {
        if (this->m_pulsating){
            if (this->sca.x < 1.5 && this->m_increasing){
                this->sca.setAll(this->sca.x + dt);
                if (this->sca.x >= 1.5)this->m_increasing = NO;
            }
            else{
                this->sca.setAll(this->sca.x - dt);
                if (this->sca.x <= 0.65)this->m_increasing = YES;
            }
        }
        
        if (this->touchEvent.phase == UITouchPhaseEnded){
            this->active = false;
        }
        else if (this->touchEvent.phase == UITouchPhaseBegan || this->touchEvent.phase == UITouchPhaseStationary){
            CGPoint pt = [this->touchEvent locationInView:this->view];
            GLfloat ratio = g_gfxWidth / g_gfxHeight;
            GLfloat x = (pt.y / g_gfxWidth * 2 * ratio) - ratio;
            GLfloat y = (pt.x / g_gfxHeight * 2 ) - 1;
            
            this->loc.set( x, y, 0 );
            
        }
    }
    
public:
    UITouch *touchEvent;
    UIView *view;
    BOOL m_increasing;
    BOOL m_pulsating;
    
    
};

class ProjectileObject : public TextureObject{
    

public:
    ProjectileObject(GLuint texture, Vector3D velocity, Vector3D min, Vector3D max) : TextureObject(texture){
        m_vel = velocity;
        m_min = min;
        m_max = max;
        
        
    }
private:

    
    void checkWalls(){
        //NSLog(@"check x:%f, y: %f", this->loc.x, this->loc.y);
        GLfloat radius = this->sca.x/2;
        
        if (this->loc.x - m_min.x < radius && this->m_vel.x < 0.0){
            //NSLog(@"bumped the left wall");
            this->m_vel.x = -this->m_vel.x;
            g_wall_sound->noteOn(8.0, 1.0);

        }
        if (this->loc.y - m_min.y < radius && this->m_vel.y < 0.0){
            //NSLog(@"bumped the bottom wall");
            this->m_vel.y = -this->m_vel.y;
            g_wall_sound->noteOn(8.0, 1.0);

            
        }
        if (m_max.x - this->loc.x < radius && this->m_vel.x > 0.0){
            //NSLog(@"bumped the right wall");
            this->m_vel.x = -this->m_vel.x;
            g_wall_sound->noteOn(8.0, 1.0);


        }
        if (m_max.y - this->loc.y < radius && this->m_vel.y > 0.0){
            //NSLog(@"bumped the top wall");
            this->m_vel.y = -this->m_vel.y;
            g_wall_sound->noteOn(8.0, 1.0);

        }
        
        
    }
    
    
    virtual void update( double dt )
    {
        m_vel.x += ShotGlobals::x_pull * dt * ShotGlobals::gravity * 20.0;
        m_vel.y += ShotGlobals::y_pull * dt * ShotGlobals::gravity * 20.0;

        m_vel *= (0.75 + 0.25*(1.0-ShotGlobals::damping));
        checkWalls();
        this->loc += m_vel*dt;
        
        
    }
public:
     Vector3D m_vel;
     Vector3D m_min;
     Vector3D m_max;
};





std::vector<Entity *> g_entities;
std::vector<TouchObject *> g_sling_ends;
std::vector<ProjectileObject *>g_projectiles;
//Entity *g_fingerProjectile = NULL;
TouchObject *g_fingerProjectile = NULL;


// function prototypes
void renderWaveform();
void renderEntities();
Entity * getFreeEntity();
void renderRubberBand();


void accelCallback( double x, double y, double z, void * data )
{
    ShotGlobals::x_pull = -y;
    ShotGlobals::y_pull = x;
    //NSLog(@"float x %f", x);
    //NSLog(@"float y %f", y);
    
    //NSLog(@"float z %f", z);
    if (z > 1.0 && g_projectiles.size() > 0 && ShotGlobals::enableClear){
        ShotGlobals::clearProjectile = true;
    }


}


//-----------------------------------------------------------------------------
// name: audio_callback()
// desc: audio callback, yeah
//-----------------------------------------------------------------------------
void audio_callback( Float32 * buffer, UInt32 numFrames, void * userData )
{
    // our x
    SAMPLE x = 0;
    // increment
    SAMPLE inc = g_waveformWidth / numFrames;

    // zero!!!
    memset( g_vertices, 0, sizeof(SAMPLE)*FRAMESIZE*2 );
    
    for( int i = 0; i < numFrames; i++ )
    {
        // set to current x value
        g_vertices[2*i] = x;
        // increment x
        x += inc;
        // set the y coordinate (with scaling)
        g_vertices[2*i+1] = buffer[2*i] * 2;
        // zero
        //buffer[2*i] = buffer[2*i+1] = 0;
        buffer[2*i] = buffer[2*i+1] =  g_mandolin->tick() + g_colliding_sound->tick() * 0.5 + g_wall_sound->tick() ;
    }
    
    // save the num frames
    g_numFrames = numFrames;
    
    // NSLog( @"." );
}




//-----------------------------------------------------------------------------
// name: touch_callback()
// desc: the touch call back
//-----------------------------------------------------------------------------
void touch_callback( NSSet * touches, UIView * view,
                    std::vector<MoTouchTrack> & tracks,
                    void * data)
{
    // points
    CGPoint pt;
    CGPoint prev;
    
    // number of touches in set
    NSUInteger n = [touches count];
    //NSLog( @"total number of touches: %d", n );
    
    // iterate over all touch events
    for( UITouch * touch in touches )
    {
        // get the location (in window)
        pt = [touch locationInView:view];
        prev = [touch previousLocationInView:view];
        
        
        // check the touch phase
        switch( touch.phase )
        {
            // begin
            case UITouchPhaseBegan:
            {
                //NSLog( @"number: %d", g_entities.size() );

                // find a free one
                if (g_sling_ends.size() == 2 && g_fingerProjectile == NULL){
                    //create a projectile instead
                    Entity * e = new TouchObject(g_texture[1], NO);
                    g_fingerProjectile = (TouchObject *)e;
                    // check
                    if( e != NULL )
                    {
                        // append
                        g_entities.push_back( e );
                        // active
                        e->active = true;
                        // reset transparency
                        e->alpha = 1.0;
                        // set color
                        e->col.set( 1, 0, 0 );
                        // set scale
                        e->sca.setAll(.5);
                        ((TouchObject *)e)->touchEvent = touch;
                        ((TouchObject *)e)->view = view;
                    }
                    
                    
                }
                else if (g_sling_ends.size() < 2){
                    
                    //sling end
                    Entity * e = new TouchObject(g_texture[0], YES);
                    // check
                    if( e != NULL )
                    {
                        // append
                        g_sling_ends.push_back((TouchObject *)e);
                        g_entities.push_back( e );
                        // active
                        e->active = true;
                        // reset transparency
                        e->alpha = 1.0;
                        // set location
                        //e->loc.set( x, y, 0 );
                        // set color
                        e->col.set( .5, 1, .5 );
                        // set scale
                        e->sca.setAll( .65 );
                        ((TouchObject *)e)->touchEvent = touch;
                        ((TouchObject *)e)->view = view;
                    }
                }
                
                break;
            }
            case UITouchPhaseStationary:
            {
                NSLog( @"touch stationary... %f %f", pt.x, pt.y );
                break;
            }
            case UITouchPhaseMoved:
            {

                break;
            }
                // ended or cancelled
            case UITouchPhaseEnded:
            {

                break;
            }
            case UITouchPhaseCancelled:
            {
                NSLog( @"touch cancelled... %f %f", pt.x, pt.y );
                break;
            }
                // should not get here
            default:
                break;
        }
    }
}



// initialize the engine (audio, grx, interaction)
void GLamorInit()
{
    //NSLog( @"init..." );
    
    
    // generate texture name
    glGenTextures( 2, &g_texture[0] );
    // bind the texture
    glBindTexture( GL_TEXTURE_2D, g_texture[0] );
    // setting parameters
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    // load the texture
    MoGfx::loadTexture( @"SlingEnd", @"png" );
    
    
    // bind the texture
    glBindTexture( GL_TEXTURE_2D, g_texture[1] );
    // setting parameters
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    // load the texture
    MoGfx::loadTexture( @"Projectile", @"png" );
    
    
    static bool initialized = NO;
    if (!initialized){
        initialized = YES;

        // set touch callback
        MoTouch::addCallback( touch_callback, NULL );
        
        g_mandolin = new stk::Mandolin(440.0);
        g_colliding_sound = new stk::Shakers();
        g_colliding_sound->controlChange(20, 56.0);
        g_wall_sound = new stk::Shakers();
        g_wall_sound->controlChange(8, 56.0);
        //g_mandolin->noteOff(0.0);
        //g_mandolin->setFrequency(440.0);
        MoAccel::addCallback(accelCallback, NULL);
        MoAccel::setUpdateInterval(0.0);
        
        // init
        bool result = MoAudio::init( SRATE, FRAMESIZE, NUM_CHANNELS );
        if( !result )
        {
            // do not do this:
            int * p = 0;
            *p = 0;
        }
        // start
        result = MoAudio::start( audio_callback, NULL );
        if( !result )
        {
            // do not do this:
            int * p = 0;
            *p = 0;
        }
    }
    

    
}

// set graphics dimensions
void GLamorSetDims( GLfloat width, GLfloat height )
{
    //NSLog( @"set dims: %f %f", width, height );
    g_gfxWidth = width;
    g_gfxHeight = height;
    
    g_waveformWidth = width / height * 1.9;
}

// draw next frame of graphics
void GLamorRender()
{
    // refresh current time reading
    MoGfx::getCurrentTime( true );
    
    // projection
    glMatrixMode( GL_PROJECTION );
    // reset
    glLoadIdentity();
    // alternate
    GLfloat ratio = g_gfxWidth / g_gfxHeight;
    glOrthof( -ratio, ratio, -1, 1, -1, 1 );
    // orthographic
    // glOrthof( -g_gfxWidth/2, g_gfxWidth/2, -g_gfxHeight/2, g_gfxHeight/2, -1.0f, 1.0f );
    // modelview
    glMatrixMode( GL_MODELVIEW );
    // reset
    // glLoadIdentity();
    
    glClearColor( 0, 0, 0, 1 );
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    
    // push
    glPushMatrix();

    // entities
    renderEntities();
    


    // waveform
    renderWaveform();
    
    //rubberband
    renderRubberBand();
    


    // pop
    glPopMatrix();
}

void renderRubberBand(){
    if (g_fingerProjectile == NULL && g_sling_ends.size() == 2){
        GLfloat bandCoords[4];
        TouchObject *first = g_sling_ends.front();
        TouchObject *last = g_sling_ends.back();
        bandCoords[0] = first->loc.x;
        bandCoords[1] = first->loc.y;
        bandCoords[2] = last->loc.x;
        bandCoords[3] = last->loc.y;
        glVertexPointer( 2, GL_FLOAT, 0, bandCoords );
        glEnableClientState( GL_VERTEX_ARRAY );
        
        // color
        glColor4f( 1, 1, 0, 1 );
        // draw the thing
        glDrawArrays( GL_LINE_STRIP, 0, 2);
    }
    else if (g_fingerProjectile != NULL && g_sling_ends.size() == 2){
        GLfloat bandCoords[6];
        TouchObject *first = g_sling_ends.front();
        TouchObject *last = g_sling_ends.back();

        
        bandCoords[0] = first->loc.x;
        bandCoords[1] = first->loc.y;
        bandCoords[2] = g_fingerProjectile->loc.x;
        bandCoords[3] = g_fingerProjectile->loc.y;
        bandCoords[4] = last->loc.x;
        bandCoords[5] = last->loc.y;
        
        
        glVertexPointer( 2, GL_FLOAT, 0, bandCoords );
        glEnableClientState( GL_VERTEX_ARRAY );
        
        // color
        glColor4f( 1, 1, 0, 1 );
        // draw the thing
        glDrawArrays( GL_LINE_STRIP, 0, 3);
        
    }
    
}


void renderWaveform()
{
    glPushMatrix();
    
    // center it
    glTranslatef( -g_waveformWidth / 2, 0.75, 0 );
    
    glScalef(0.3, 0.3, 1.0);
    
    // set the vertex array pointer
    glVertexPointer( 2, GL_FLOAT, 0, g_vertices );
    glEnableClientState( GL_VERTEX_ARRAY );
    
    // color
    glColor4f( 1, 1, 0, 1 );
    // draw the thing
    glDrawArrays( GL_LINE_STRIP, 0, g_numFrames/2 );
    
    // color
    glColor4f( 0, 1, 0, 1 );
    // draw the thing
    glDrawArrays( GL_LINE_STRIP, g_numFrames/2-1, g_numFrames/2 );
    glPopMatrix();

}
void adjustLocation(ProjectileObject *projectile, float distance){
    NSLog(@"swap was called");
    if (projectile->m_vel.x < 0){
        projectile->loc.x -= distance*2;
    }
    else{
        projectile->loc.x += distance*2;
    }
    if (projectile->m_vel.y < 0){
        projectile->loc.y -= distance*2;
    }
    else{
        projectile->loc.y += distance*2;
    }
}

void checkOtherProjectilesForCollisions(){
    
    for (int first = 0; first < g_projectiles.size(); first++){
        for (int second = first+1; second < g_projectiles.size(); second++){
            ProjectileObject *firstProjectile = g_projectiles[first];
            ProjectileObject *secondProjectile = g_projectiles[second];
            GLfloat diameter = 0.5*firstProjectile->sca.x + 0.5*secondProjectile->sca.x;
            if ((firstProjectile->loc - secondProjectile->loc).magnitude() < diameter){
                //NSLog(@"a collision occured!");
                Vector3D tmp;
                tmp = firstProjectile->m_vel;
                firstProjectile->m_vel = secondProjectile->m_vel;
                secondProjectile->m_vel = tmp;
                
                //reset locations to not clash

                float total_overlap = diameter - (firstProjectile->loc - secondProjectile->loc).magnitude();
                //NSLog(@"total overlap is %f", total_overlap);
                float indiv_overlap = total_overlap/2.0;
                if (indiv_overlap > 0){
                    adjustLocation(firstProjectile, indiv_overlap);
                    adjustLocation(secondProjectile, indiv_overlap);
                }

                float new_overlap = diameter - (firstProjectile->loc - secondProjectile->loc).magnitude();
                //NSLog(@"total newoverlap is %f", new_overlap);
            
                

                g_colliding_sound->noteOn(20.0, 1.0);
            }
        }
    }
    
    
}

void renderEntities()
{
    
    if (ShotGlobals::clearProjectile && g_projectiles.size() > 0){
        vector<ProjectileObject *>::iterator i;
        for (i = g_projectiles.begin(); i != g_projectiles.end();){
            (*i)->active = false;
            i = g_projectiles.erase(i);
        }
        ShotGlobals::clearProjectile = false;
    }

    vector<Entity *>::iterator e;
    vector<TouchObject *>::iterator s;
    
    
    
    if (g_fingerProjectile != NULL && !g_fingerProjectile->active){
        
        
        if (g_sling_ends.size() == 2){
            //NSLog(@"Pluck!");
            g_mandolin->setFrequency(440.0);
            
            float distance_between_ends = (g_sling_ends.front()->loc - g_sling_ends.back()->loc).magnitude();
            float lengthLeftPluck = (g_sling_ends.front()->loc - g_fingerProjectile->loc).magnitude();
            float lengthRightPluck = (g_sling_ends.back()->loc - g_fingerProjectile->loc).magnitude();
            float pluckPos = lengthLeftPluck / (lengthLeftPluck + lengthRightPluck);
            
            float diagonal = sqrt(g_ratio*g_ratio*4 + 1*1*4);
            float freq = 200.0/(0.5*(distance_between_ends/(diagonal)));
            
            g_mandolin->setPluckPosition(pluckPos);
            g_mandolin->setFrequency(freq);
            //NSLog(@"diagonal: %f", diagonal);
            //NSLog(@"length: %f", distance_between_ends);
            //NSLog(@"freq: %f", freq);
            g_mandolin->pluck(1.0, pluckPos);
            //and create moving projectile
            
            Vector3D midpoint = (g_sling_ends.front()->loc + g_sling_ends.back()->loc);
            midpoint *= 0.5;
            Vector3D diff = midpoint - g_fingerProjectile->loc;
            Vector3D initial_velocity = diff * 2;
            
            Vector3D min_walls(-g_ratio, -1, 0);
            Vector3D max_walls(g_ratio, 1, 0);
            ProjectileObject *launched_projectile = new ProjectileObject(g_texture[1], initial_velocity, min_walls, max_walls );
            g_entities.push_back(launched_projectile);
            g_projectiles.push_back(launched_projectile);
            launched_projectile->active = true;
            // reset transparency
            launched_projectile->alpha = 1.0;
            // set color
            launched_projectile->col.set( 1, 0, 0 );
            // set scale
            launched_projectile->sca.setAll( .5 );
            launched_projectile->loc = g_fingerProjectile->loc;
            
            
        }
        g_fingerProjectile = NULL;
        
    }

    for (s = g_sling_ends.begin(); s != g_sling_ends.end();){
        if (!(*s)->active){
            s = g_sling_ends.erase(s);
        }
        else{
            ++s;
        }
    }
    if (g_fingerProjectile != NULL && g_sling_ends.size() < 2){
        vector<TouchObject *>::iterator i;
        for (i = g_sling_ends.begin(); i != g_sling_ends.end(); i++){
            (*i)->active = FALSE;
        }
        g_fingerProjectile->active = FALSE;
        
    }
    for( e = g_entities.begin(); e != g_entities.end(); /*e++*/ )
    {
        // check if active
        if( (*e)->active == FALSE )
        {
            // delete
            delete (*e);
            e = g_entities.erase( e );
        }
        else{
            //check for other projectiles for collisions
            checkOtherProjectilesForCollisions();
            (*e)->update( MoGfx::delta() );
            
            // push
            glPushMatrix();
            
            // translate
            glTranslatef( (*e)->loc.x, (*e)->loc.y, (*e)->loc.z );
            // rotate
            glRotatef( (*e)->ori.x, 1, 0, 0 );
            glRotatef( (*e)->ori.y, 0, 1, 0 );
            glRotatef( (*e)->ori.z, 0, 0, 1 );
            // scale
            glScalef( (*e)->sca.x, (*e)->sca.y, (*e)->sca.z );
            
            // color
            glColor4f( (*e)->col.x, (*e)->col.y, (*e)->col.z, (*e)->alpha );
            
            // render
            (*e)->render();
            
            // pop
            glPopMatrix();
            
            ++e;
        }

    }
}



//-----------------------------------------------------------------------------
// name: getFreeEntity()
// desc: ...
//-----------------------------------------------------------------------------
//Entity * getFreeEntity()
//{
//    // for each entity
//    for( int i = 0; i < NUM_ENTITIES; i++ )
//    {
//        if( g_entities[i].active == false )
//        {
//            g_entities[i].active = true;
//            g_entities[i].alpha = 1;
//            return &g_entities[i];
//        }
//    }
//    
//    return NULL;
//}

