local ffi = require('ffi')

ffi.cdef([[
  // https://github.com/openssl/openssl/blob/4ace4ccda2934d2628c3d63d41e79abe041621a7/include/openssl/ossl_typ.h
  typedef struct x509_store_st X509_STORE;
  typedef struct x509_st X509;
  typedef struct X509_crl_st X509_CRL;
  typedef struct bio_st BIO;
  typedef struct bio_method_st BIO_METHOD;

  unsigned long ERR_get_error(void);
  const char *ERR_reason_error_string(unsigned long e);
]])

local C = ffi.C
local _M = { }

local error = error

local function openssl_error()
  local code, reason

  while true do
    --[[
    https://www.openssl.org/docs/man1.1.0/crypto/ERR_get_error.html

      ERR_get_error() returns the earliest error code
      from the thread's error queue and removes the entry.
      This function can be called repeatedly
      until there are no more error codes to return.
    ]]--
    code = C.ERR_get_error()

    if code == 0 then
      break
    else
      reason = C.ERR_reason_error_string(code)
    end
  end

  return ffi.string(reason)
end

local function ffi_assert(ret, expected)
  if not ret or ret == -1 or (expected and ret ~= expected) then
    error(openssl_error(), 2)
  end

  return ret
end

_M.ffi_assert = ffi_assert
_M.openssl_error = openssl_error

return _M