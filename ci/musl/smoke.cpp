#include <zlib.h>
#include <cstdio>
#include <cstring>
int main() {
  const char input[]="InsightOS musl zlib release";
  unsigned char compressed[256], decoded[256];
  uLongf size=sizeof(compressed), decoded_size=sizeof(decoded);
  if (compress(compressed,&size,reinterpret_cast<const Bytef*>(input),sizeof(input))!=Z_OK) return 1;
  if (uncompress(decoded,&decoded_size,compressed,size)!=Z_OK) return 2;
  if (decoded_size!=sizeof(input) || std::memcmp(decoded,input,sizeof(input))) return 3;
  if (std::strcmp(zlibVersion(),"1.3.2")) return 4;
  std::puts("PASS: zlib compression roundtrip");
}
