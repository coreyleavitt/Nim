#include <stdio.h>
int libA(void); int libB(void);
void ANimMain(void); void BNimMain(void);
int main(void) { ANimMain(); BNimMain(); printf("%d %d\n", libA(), libB()); return !(libA()==3 && libB()==3); }
