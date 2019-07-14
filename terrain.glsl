
precision highp float;

#define LACU 2.0
#define MAXGRASSSTEEP 0.4
#define MAXGRASSALTITUDE .8
#define MAXSNOWSTEEP   0.35
#define MAXSNOWALTITUDE 0.4
#define NORMALEPSILON 0.02
#define SEALEVEL 0.01 //std 0.3
#define CAMERAALTITUDE 1.3 //std 1.0
#define CAMERASCREENDISTANCE 0.5 //std 0.4
#define LOWITER 5
#define HIGHITER 8
#define COLORITER 5
#define PENUMBRAFACTOR 0.01




/* ****************************************************************** */
float conv(float f) {
	f*=f*f*f;  //sealevel 0.01 - flat landscape with few hills
	//f = f *(f *(f *(16.5333 - 6.4 * f )-13.6)+4.46667);
	//f = f* (f* (f* (f* (33.4169-13.3668 *f)-29.2398)+10.4428)-0.253133); // plains with holes
	//f = f* (f* (f* (f* (f* (119.616-40.3125 *f)-131.004)+63.0956)-11.5608)+1.16577);
    if (f < SEALEVEL){f = SEALEVEL;}
    return f;
}


// ***** noise code ***************************************************
// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

//iq hash
float hash( float n )
{
    return fract(sin(n)*54321.98761234);  // value has no meaning that I could find
}

//iq derivative noise function
// returns vec3(noise, dnoise/dx, dnoise/dy)
vec3 noised(vec2 pos )
{
    vec2 p = floor(pos);
    vec2 f = fract(pos);
    
    vec2 u = (10.0+(-15.0+6.0*f)*f)*f*f*f;  // f=6*x^5-15*x^4+10*x^3  df/dx=30*x^4-60*x^3+30*x^2; horner of df is 30.0*f*f*(f*(f-2.0)+1.0)
    
    float n = p.x + p.y*57.0;
    
    float a = hash(n+  0.0);
    float b = hash(n+  1.0);
    float c = hash(n+ 57.0); // do not know why 57 & 58
    float d = hash(n+ 58.0);
    
    return vec3( a+(b-a)*u.x+(c-a)*u.y+(a-b-c+d)*u.x*u.y,
    30.0*f*f*(f*(f-2.0)+1.0) * (vec2(b-a,c-a)+(a-b-c+d)*u.yx) );
    
}

//iq  noise function
float noise(vec2 x )
{
    vec2 p = floor(x);
    vec2 f = fract(x);
    
    f= (10.0+(-15.0+6.0*f)*f)*f*f*f; // smooth
    
    float n = p.x + p.y*57.0;
    
    float res = mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
    mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y);
    
    return res;
}


/* ****************************************************************** */


/* ****************************************************************** */


// fractional brownian motion
// iter is number of octaves

vec3 fbmDerivative(vec2 p, int iter) {
    
    float f = 0.0;
	float dfx = 0.0;
	float dfy = 0.0;
    float fLacunarity = LACU;
    
	float amplitude = 0.5;
	float sumAmplitude = 0.0;
		
	for (int i=0;i<20;i++) {
		vec3 value = noised( p ); 
		
		f += amplitude * value.x;
		dfx +=  value.y;
		dfy +=  value.z;
		p = p * fLacunarity; 
		sumAmplitude+=amplitude;
		amplitude/=2.0;
		if (i>iter) {break;}
	}
	f/=sumAmplitude;
	
    return vec3( conv(f), dfx, dfy);
}

// same as above, without derivatives
float fbm(vec2 p, int iter){
	int idx=0;
    float f = 0.0;
	float amplitude = 0.5;
	float sumAmplitude = 0.0;
	for (int i=0;i<20;i++) {
		float value = noise( p ); 
		f += amplitude * value;
		p = p * LACU; 
		sumAmplitude+=amplitude;
		amplitude/=2.0;
		if ( i>iter ) {break;}
	}
	f/=sumAmplitude;
    return conv(f);
}

vec3 getNormal( vec3 p, int iter ) {
	//using noise derivative
	//not sure this code is correct
    vec3 value;
	value = fbmDerivative( p.xz, iter);
	if (value.x <= SEALEVEL) { return vec3(.0,1.0,.0); } //sea is flat
	float dfx=value.y;
	float dfz=value.z;
	
	return normalize(vec3( -value.y, 1.0, -value.z));
}

// #####################################################################
vec3 GenerateTerrainColor(vec3 position, vec3 normal) {
    float x = position.x;
    float y = position.z;
    float z = position.y;
	float n = getNormal(position,COLORITER).y;
    float l = 1.0;
    vec3 terrainColor;
    vec3 cmin,cmax;
    
    // notes
    
//Surface de lac 0,02 Ã  0,04 
//ForÃªt de conifÃ¨res 0,05 Ã  0,15 
//Surface de la mer 0,05 Ã  0,15 
//Sol sombre 0,05 Ã  0,15 
//Cultures 0,15 Ã  0,25 
//Sable lÃ©ger et sec 0,25 Ã  0,45 
//Calcaire[1] environ 0,40 
//Glace environ 0,60 
//Neige tassÃ©e 0,40 Ã  0,70 
//Neige fraÃ®che 0,75 Ã  0,90 
//Miroir parfait 1 

    
    // *** palette ***
    
    // water
    vec3 ocean      = vec3( 0.08, .12, .5);
    vec3 shore      = vec3( 0.1, .2,.6);
    
    // base layer
    vec3 beach      = vec3(224.0, 202.0, 181.0)/255.0; 
    vec3 earth      = vec3(239.0, 200.0, 143.0)/255.0; 
    vec3 calcaire   = vec3(132.0, 50.0, 50.0)/255.0;  // marron rouge
    vec3 rocks      = vec3(105.0, 85.0, 110.0)/255.0; // gris
    
    // grass layer
    vec3 grass1 = vec3 (8.0, 24.0, 4.0)/255.0;
    vec3 grass2 = vec3 (16.0, 48.0, 4.0)/255.0;
    
    // snow layer
    vec3 snow1 = vec3 ( .78,.78,.78);
    vec3 snow2 = vec3 ( .9,.9,.9);
    
    if ( z <= SEALEVEL) {
        //water
        terrainColor = mix (ocean, shore , smoothstep( 0.0, 1.0,  noise( position.xz * 16.0)) );    
		//terrainColor=shore;
        return terrainColor;
    }
    
    
	// add some noise
	// input noise divisor define size of stains in transition areas
    // multiplicator define the size of the range of altitude with mixed color
    z += noise( position.xz * 32.0 )* 0.1;   
    
    // base color
    terrainColor = mix (        beach,    earth, smoothstep(SEALEVEL    , SEALEVEL+0.1 , z) );
    terrainColor = mix ( terrainColor, calcaire, smoothstep(SEALEVEL+0.1, SEALEVEL+0.3 , z) );
    terrainColor = mix ( terrainColor,    rocks, smoothstep(SEALEVEL+0.3,          1.0  , z) );
    
    //add grass
    if (( n > MAXGRASSSTEEP ) && ( z <  MAXGRASSALTITUDE )) {
        terrainColor = mix( grass1, grass2, smoothstep(0.0 , 1.0, noise( position.xz * 32.0 )));
    }
    
    // add snow
    if (( n > MAXSNOWSTEEP) && ( z > MAXSNOWALTITUDE )) {
        return mix( snow1, snow2, smoothstep(0.0 , 1.0, noise( position.xz * 1.0 )*0.1));
	}
    return vec3(terrainColor);;
}



// ###################################################################



// ###################################################################
vec4 castRay( vec3 startPosition, vec3 lookatDirection )  {
    // return vec4 = last worldPosition, 1 if terrain / 0 if sky
    float step = 0.03;
    float lastStep;
    float altitude = 0.0;
    float lastAltitude;
    float lastY;
    float walkStep = 0.0;
    vec3 p;
	float delta;
    lastStep=step;
    for( int i = 0; i < 180; i++ ) { // GLSL limitation: loop on int only
        p = startPosition + lookatDirection * walkStep;
        altitude = fbm( vec2(p.x, p.z),LOWITER);
		delta = p.y -  altitude;
        if(delta<0.0 ){
            // we are under floor: linear interpolate the intersect
            walkStep = walkStep - lastStep + lastStep*(lastAltitude-lastY)/(p.y-lastY-altitude+lastAltitude);
            p = startPosition + lookatDirection * walkStep;
            altitude = fbm( vec2(p.x, p.z),HIGHITER ); //high definition altitude
            return vec4(p.x,altitude,p.z,walkStep);
        }
        if( p.y <  0.001){
			// under the flow, exit
            walkStep = walkStep - lastStep + lastStep*(lastAltitude-lastY)/(p.y-lastY-altitude+lastAltitude);
            p = startPosition + lookatDirection * walkStep;
            return vec4(p.x,0,p.z,walkStep);
        }
        if (p.y > 5.0) {break;} // far in the sky
        lastAltitude = altitude;
        lastStep=step;
        lastY = p.y;
        step = max(max(0.05,.5*delta) , float(i)/2000.0); // step is big when far from floor and far from camera
		//step+=0.0005;
        walkStep += step;
        
    }
    return  vec4(p.x,p.y,p.z,-walkStep);  
}

// ###################################################################

vec3 calcLookAtDirection( vec3 cP, vec3 cD, float screenDistance, vec2 z ){
    // cameraPosition
    // cameraDirection
    // camera-screen distance
    // position of pixel on screen
    
    // normalize camera direction
    vec3 cDnorm = normalize (cD);
    
    // we are looking for u & v, the unity vectors on screen, in world coordinates
    // we know that u is // to surface (since we locked horizon at horizontal ):its Y is 0
    // we know that cDnorm is perpendicular to u
    // we project to surface to find u.x and u.y
    vec3 u = vec3(cDnorm.z, 0.0,cDnorm.x);
    
    vec3 v = cross( cDnorm, u);
    
    //screen point 0,0 in world coordiante
    vec3 screenPointOO = cP + cDnorm * screenDistance;
    
    //z in world coordiantes
    vec3 screenPointInWorld= screenPointOO + u*z.x + v*z.y;
    
    return  (screenPointInWorld-cP);
    
}

// #################################################################

vec3 calcStartPosition( vec3 cP, vec3 cD, float screenDistance, vec2 z ){
    // cameraPosition
    // cameraDirection
    // camera-screen distance
    // position of pixel on screen
    
    // normalize camera direction
    vec3 cDnorm = normalize (cD);
    
    // we are looking for u & v, the unity vectors on screen, in world coordinates
    // we know that u is // to surface =&gt; its Y is 0
    // we know that cDnorm is perpendicular to u
    // we project to surface to find u.x and u.y
    vec3 u = vec3(cDnorm.z, 0.0,cDnorm.x);
    
    vec3 v = cross( cDnorm, u);
    
    //screen point 0,0 in world coordiante
    vec3 screenPointOO = cP + cDnorm * screenDistance;
    
    //z in world coordiantes
    vec3 screenPointInWorld= screenPointOO + u*z.x + v*z.y;
    
    return  screenPointInWorld;
    
}

// #################################################################
vec3 getNormal( vec3 p ) {
	//noise derivative
    vec3 value;
	value = fbmDerivative( p.xz, HIGHITER);
	if (value.x <= SEALEVEL) { return vec3(.0,1.0,.0); }
	float dfx=value.y;
	float dfz=value.z;
	//float vy = 1.0 ;	vy -= dfx*dfx + dfz*dfz;vy=sqrt(vy);
	
	return normalize(vec3( -value.y, 1.0, -value.z));
}


 vec3 getNormalC( vec3 p ) {
	//central differences
    float eps=NORMALEPSILON;
    vec3  n = vec3( fbm( vec2(p.x-eps,p.z), HIGHITER ) - fbm( vec2(p.x+eps,p.z), HIGHITER ), 
				  	2.0*eps,
    				fbm(vec2(p.x,p.z-eps), HIGHITER ) - fbm(vec2(p.x,p.z+eps), HIGHITER ) );
    return normalize( n );
}


// #################################################################
float castRay2Sun( vec3 startPosition, vec3 lookatDirection )  {
    float step = 0.03;
    float lastStep;
    float altitude = 0.0;
    float lastAltitude;
    float lastY;
    float walkStep = 0.0;
	float delta;
    float result = 1.0;
    vec3 p;
    lastStep=step;
    for( int i = 0; i < 20; i++ ) { // GLSL limitation: loop on int only
        walkStep += step;
        p = startPosition + lookatDirection * walkStep;
        altitude = fbm( vec2(p.x, p.z) , HIGHITER);
		delta = p.y -  altitude;
        
        // if we are about to intersect (=> delta is small)
        // and we are not too far from our starting point ( / walkStep)
        // we are on the border of the penumbra
        // so we can shade by penumbrafactor + constantThatDefineBorderSize * delta/walkstep
        result = min( result, PENUMBRAFACTOR + 16.0 * delta / walkStep );
		
        if( delta < .0){
			return PENUMBRAFACTOR; //penombre 
        }        
        
        
    }
    return result;  
    //return 1.0;
}

vec3 getShading( vec3 position , vec3 normal ) {
    vec3 uAmbientColor = vec3 (0.18, 0.18, 0.2) / 2.0;         // ambiant light color
    vec3 uLightingDirection = vec3(-0.9, 0.2, 0.1); // sunlight direction
    vec3 uDirectionalColor = vec3( 1.47, 1.35, 1.25);  // sunlight color
    
    float penombre = 1.0;
    vec3 color;
    
    // march to sun. if we intersect a moutain, we are in its shadow
    penombre = castRay2Sun(  position ,uLightingDirection) ;
    //if (castRay2Sun(  position ,uLightingDirection) < 1.0) {penombre=vec3(0.1);}
    
    
    //directional lightning (sun)
    float directionalLightWeighting = max(dot(normal, uLightingDirection), 0.0);
    
    //final lightning: ambiant, sun, penumbra
    color = uAmbientColor;
    color += uDirectionalColor * directionalLightWeighting * penombre;
    
	//color = vec3(1.0, 1.0, 1.0) * penombre; // usefull to debug penumbra
    
    return color;
    
}

// #################################################################

vec4 applyFog ( vec3 color, float far) {
	//just to hide clipping
    return vec4( mix( color ,vec3(0.5,0.5,0.6), smoothstep(0.0,1.0,far/25.0) ) ,1.0);
}

// #################################################################

vec4 colorize(vec3 startPosition, vec3 lookatDirection, vec4 position) {
    
    vec3 p = position.xyz; //startPosition + lookatDirection * position.w;
    vec3 n = getNormal( p );
    vec3 s = getShading( p, n );
    vec3 m = GenerateTerrainColor( position.xyz, n ); //getMaterial( p, n );
    return applyFog( m * s, position.w );
    
    //return vec4(  m *s ,1.0);
    
}

// ###################################################################
void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    
    vec3 uCameraXYZ = vec3( 0.0, CAMERAALTITUDE, 0.0); // camera postion
    vec3 uCameraDirXYZ = vec3(0, -0.40, .707160) ; // camera direction
    vec4 color;
    
    uCameraXYZ.z = iTime/1.9;
	
    
    float uScreenDistance = CAMERASCREENDISTANCE;  // distance camera/screen
    
    
    float sx=float(iResolution.x);
    float sy=float(iResolution.y);
    vec2 z,zn;
    
    z.x = fragCoord.x / sx - 0.5;
    z.y = fragCoord.y / sy - 0.5;
    
    vec3 lookatDirection = calcLookAtDirection( uCameraXYZ,uCameraDirXYZ, uScreenDistance, z );
    vec3 startPosition  = calcStartPosition( uCameraXYZ, uCameraDirXYZ, uScreenDistance, z );
    
    vec4 gotcha = castRay( startPosition, lookatDirection );
    
    if (gotcha.w > 0.0 ) {
        color = colorize( startPosition, lookatDirection, gotcha);
        } else {
        // sky color;
        color = vec4( mix ( vec3(0.7,0.9,1.0), vec3(0.5,0.5,0.6), smoothstep(0.0,1.0,-gotcha.w/30.0)), 1.0);
        
    }
    
    // gamma correction
    fragColor = pow( color, vec4(1.0/2.2,1.0/2.2,1.0/2.2,1.0) );
    
}   // main
