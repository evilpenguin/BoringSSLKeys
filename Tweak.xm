//
// Created by EvilPenguin (James Emrich)
// BoringSSL
// Date: 4/26/2020
//
//
//

#import <mach-o/dyld.h>
#import <CydiaSubstrate.h>

static void _write_to_file(const char *line) {
    if (line != NULL) {
        NSMutableString *lineString = [NSMutableString stringWithUTF8String:line];
        if (lineString.length > 0) {
            // Add new line
            [lineString appendString:@"\n"];

            // Get Cache directory
            NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
            NSString *logPath = [cachesDirectory stringByAppendingPathComponent:@"BoringSLLKey.keylog"];
            NSLog(@"[BoringSSLKey] Writing to: %@", logPath);

            // Write empty file
            if (![NSFileManager.defaultManager fileExistsAtPath:logPath]) {
                [NSData.data writeToFile:logPath atomically:YES];
            } 

            // Write keys to file
            NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
            [handle truncateFileAtOffset:handle.seekToEndOfFile];
            [handle writeData:[lineString dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        }
    }
}

static void call_back(const void *ssl, const char *line) {
    // Log
    NSLog(@"[BoringSSLKey] %s", line);

    // Write
    _write_to_file(line);
}

/*
iOS 13.3.1 libboringssl.dylib

 __ZN4bssl14ssl_log_secretEPK6ssl_stPKcNS_4SpanIKhEE: // bssl::ssl_log_secret(ssl_st const*, char const*, bssl::Span<unsigned char const>)
0x0000000185366358 FF8301D1               sub        sp, sp, #0x60 
0x000000018536635c F65703A9               stp        x22, x21, [sp, #0x30]
0x0000000185366360 F44F04A9               stp        x20, x19, [sp, #0x40]
0x0000000185366364 FD7B05A9               stp        x29, x30, [sp, #0x50]
0x0000000185366368 FD430191               add        x29, sp, #0x50
0x000000018536636c 083440F9               ldr        x8, [x0, #0x68]        ; Offset of ctx pointer
0x0000000185366370 086141F9               ldr        x8, [x8, #0x2c0]       ; Offset of keylog_callback pointer
*/

static void (*orig_SSL_CTX_set_min_proto_version)(void *ctx, uint16_t version);
static void new_SSL_CTX_set_min_proto_version(void *ctx, uint16_t version) {
    intptr_t ctx_char = (intptr_t)ctx;
    intptr_t **keylog_callback = (intptr_t **)(ctx_char + 0x2c0); // change this offset per iOS version
    *keylog_callback = (intptr_t *)call_back;

    orig_SSL_CTX_set_min_proto_version(ctx, version);
}

%ctor {
    void *boringssl_handle = dlopen("/usr/lib/libboringssl.dylib", RTLD_NOW);
    void *SSL_CTX_set_min_proto_version = dlsym(boringssl_handle, "SSL_CTX_set_min_proto_version");
    if (SSL_CTX_set_min_proto_version) {
        MSHookFunction(SSL_CTX_set_min_proto_version, (void *)new_SSL_CTX_set_min_proto_version, (void **)&orig_SSL_CTX_set_min_proto_version);
    }
}
