// from http://www.efgh.com/software/rijndael.htm (public domain)

#ifndef H__RIJNDAEL
#define H__RIJNDAEL

#include "d0.h"

D0_EXPORT int d0_rijndael_setup_encrypt(unsigned long *rk, const unsigned char *key,
  int keybits);
D0_EXPORT int d0_rijndael_setup_decrypt(unsigned long *rk, const unsigned char *key,
  int keybits);
D0_EXPORT void d0_rijndael_encrypt(const unsigned long *rk, int nrounds,
  const unsigned char plaintext[16], unsigned char ciphertext[16]);
D0_EXPORT void d0_rijndael_decrypt(const unsigned long *rk, int nrounds,
  const unsigned char ciphertext[16], unsigned char plaintext[16]);

#define D0_RIJNDAEL_KEYLENGTH(keybits) ((keybits)/8)
#define D0_RIJNDAEL_RKLENGTH(keybits)  ((keybits)/8+28)
#define D0_RIJNDAEL_NROUNDS(keybits)   ((keybits)/32+6)

#endif
