/* strstr example */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int main ()
{
  char str[] ="/home/user/music/thomas.mp3";
  char ext[] =".mp3";

  char * pch;
  pch = strstr(str, ext);

  /* malloc enough string + \0 on the end. */
  char * basename = (char *)malloc(pch-str + 1);
  memset(basename, 0, pch-str + 1);

  /* copy in basename. */
  strncpy (basename, str, pch-str);
  puts (basename);
  return 0;
}