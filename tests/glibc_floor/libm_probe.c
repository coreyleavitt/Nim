#define _GNU_SOURCE
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <pthread.h>
int main(int c, char**v){ double x = atof(v[1]); volatile double r=0;
 r+=fmod(x,3)+atan2(x,2)+tan(x)+log2(x)+log10(x)+exp2(x)+cbrt(x)+hypot(x,1)+sinh(x)+asinh(x)+expm1(x)+log1p(x)+lgamma(x)+tgamma(x)+erf(x)+exp10(x)+fmax(x,1)+nearbyint(x)+remainder(x,2)+ldexp(x,2)+rint(x)+round(x)+trunc(x)+cosh(x)+acosh(x+2)+atanh(x/9)+exp(x)+pow(x,1.5)+log(x)+sin(x)+cos(x)+sqrt(x)+floor(x)+ceil(x)+fabs(x);
 printf("%f %p\n", r, dlopen("x",RTLD_NOW)); return 0; }
