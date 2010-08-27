#ifndef __D0_BLIND_ID_H__
#define __D0_BLIND_ID_H__

#include "d0.h"

typedef struct d0_blind_id_s d0_blind_id_t;
typedef BOOL (*d0_fastreject_function) (const d0_blind_id_t *ctx, void *pass);

EXPORT WARN_UNUSED_RESULT d0_blind_id_t *d0_blind_id_new(void);
EXPORT void d0_blind_id_free(d0_blind_id_t *a);
EXPORT void d0_blind_id_clear(d0_blind_id_t *ctx);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_copy(d0_blind_id_t *ctx, const d0_blind_id_t *src);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_generate_private_key(d0_blind_id_t *ctx, int k);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_generate_private_key_fastreject(d0_blind_id_t *ctx, int k, d0_fastreject_function reject, void *pass);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_read_private_key(d0_blind_id_t *ctx, const char *inbuf, size_t inbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_read_public_key(d0_blind_id_t *ctx, const char *inbuf, size_t inbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_write_private_key(const d0_blind_id_t *ctx, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_write_public_key(const d0_blind_id_t *ctx, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_fingerprint64_public_key(const d0_blind_id_t *ctx, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_generate_private_id_modulus(d0_blind_id_t *ctx);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_read_private_id_modulus(d0_blind_id_t *ctx, const char *inbuf, size_t inbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_write_private_id_modulus(const d0_blind_id_t *ctx, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_generate_private_id_start(d0_blind_id_t *ctx);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_generate_private_id_request(d0_blind_id_t *ctx, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_answer_private_id_request(const d0_blind_id_t *ctx, const char *inbuf, size_t inbuflen, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_finish_private_id_request(d0_blind_id_t *ctx, const char *inbuf, size_t inbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_read_private_id_request_camouflage(d0_blind_id_t *ctx, const char *inbuf, size_t inbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_write_private_id_request_camouflage(const d0_blind_id_t *ctx, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_read_private_id(d0_blind_id_t *ctx, const char *inbuf, size_t inbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_read_public_id(d0_blind_id_t *ctx, const char *inbuf, size_t inbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_write_private_id(const d0_blind_id_t *ctx, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_write_public_id(const d0_blind_id_t *ctx, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_authenticate_with_private_id_start(d0_blind_id_t *ctx, BOOL is_first, BOOL send_modulus, char *message, size_t msglen, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_authenticate_with_private_id_challenge(d0_blind_id_t *ctx, BOOL is_first, BOOL recv_modulus, const char *inbuf, size_t inbuflen, char *outbuf, size_t *outbuflen, BOOL *status);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_authenticate_with_private_id_response(d0_blind_id_t *ctx, const char *inbuf, size_t inbuflen, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_authenticate_with_private_id_verify(d0_blind_id_t *ctx, const char *inbuf, size_t inbuflen, char *msg, size_t *msglen, BOOL *status);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_authenticate_with_private_id_generate_missing_signature(d0_blind_id_t *ctx);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_fingerprint64_public_id(const d0_blind_id_t *ctx, char *outbuf, size_t *outbuflen);
EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_sessionkey_public_id(const d0_blind_id_t *ctx, char *outbuf, size_t *outbuflen); // can only be done after successful key exchange, this performs a modpow; key length is limited by SHA_DIGESTSIZE for now; also ONLY valid after successful d0_blind_id_authenticate_with_private_id_verify/d0_blind_id_fingerprint64_public_id

EXPORT WARN_UNUSED_RESULT BOOL d0_blind_id_INITIALIZE(void);
EXPORT void d0_blind_id_SHUTDOWN(void);

EXPORT void d0_blind_id_util_sha256(char *out, const char *in, size_t n);

#endif
