/* strstr + strspn example */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MAX_TOKENS  20  /* Some reasonable values */
#define MAX_STRING  128 /* Easy enought o make dynamic with mallocs */

int main ()
{
  char str[] ="/home/user/music/thomas.mp3";
  char sep[] = "./";
  char collect[MAX_TOKENS][MAX_STRING];

  memset(collect, 0, MAX_TOKENS * MAX_STRING);
  char * pch = strtok (str, sep);
  int ccount = 0;    

  if(pch != NULL) {
    /* collect all seperated text */
    while(pch != NULL) { 
        strncpy( collect[ccount++], pch, strlen(pch));
        pch = strtok (NULL, sep);
    }
  }

  /* output tokens. */
  for(int i=0; i<ccount; ++i)
    printf ("Token: %s\n", collect[i]);
  return 0;
}