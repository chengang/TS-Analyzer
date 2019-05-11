//
//  ReceiptValidation.m
//  HTTPLook
//
//  Created by ChenGang on 2016/10/20.
//  Copyright © 2016年 ChenGang. All rights reserved.
//

#import "ReceiptValidation.h"

// ASN.1 values for the App Store receipt
#define ATTR_START          1
#define BUNDLE_ID           2
#define VERSION             3
#define OPAQUE_VALUE        4
#define HASH                5
#define ATTR_END            6
#define INAPP_PURCHASE      17
#define ORIG_VERSION        19
#define EXPIRE_DATE         21

// ASN.1 values for In-App Purchase values
#define INAPP_ATTR_START	1700
#define INAPP_QUANTITY		1701
#define INAPP_PRODID		1702
#define INAPP_TRANSID		1703
#define INAPP_PURCHDATE		1704
#define INAPP_ORIGTRANSID	1705
#define INAPP_ORIGPURCHDATE	1706
#define INAPP_ATTR_END		1707
#define INAPP_SUBEXP_DATE   1708
#define INAPP_WEBORDER      1711
#define INAPP_CANCEL_DATE   1712

@implementation ReceiptValidation : NSObject

- (ReceiptValidation *)init
{
    self.receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    if ([self.receiptURL checkResourceIsReachableAndReturnError:NULL] == false) {
        return nil;
    }
    
    // Load the receipt
    NSData * receiptData = [NSData dataWithContentsOfURL:self.receiptURL];
    BIO *receiptBIO = BIO_new(BIO_s_mem());
    BIO_write(receiptBIO, [receiptData bytes], (int) [receiptData length]);
    PKCS7 * receiptPKCS7 = d2i_PKCS7_bio(receiptBIO, NULL);
    if (!receiptPKCS7) {
        return nil;
    }
    
    if (!PKCS7_type_is_signed(receiptPKCS7)) {
        return nil;
    }
    
    if (!PKCS7_type_is_data(receiptPKCS7->d.sign->contents)) {
        return nil;
    }
    
    // verify the receipt signature
    NSURL *appleRootURL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
    NSData *appleRootData = [NSData dataWithContentsOfURL:appleRootURL];
    BIO *appleRootBIO = BIO_new(BIO_s_mem());
    BIO_write(appleRootBIO, (const void *) [appleRootData bytes], (int) [appleRootData length]);
    X509 *appleRootX509 = d2i_X509_bio(appleRootBIO, NULL);
    
    X509_STORE *store = X509_STORE_new();
    X509_STORE_add_cert(store, appleRootX509);
    
    OpenSSL_add_all_digests();
    
    int result = PKCS7_verify(receiptPKCS7, NULL, store, NULL, NULL, 0);
    if (result != 1) {
        return nil;
    }
    
    // Get a pointer to the ASN.1 payload
    ASN1_OCTET_STRING *octets = receiptPKCS7->d.sign->contents->d.data;
    const unsigned char *ptr = octets->data;
    const unsigned char *end = ptr + octets->length;
    const unsigned char *str_ptr;
    
    int type = 0, str_type = 0;
    int xclass = 0, str_xclass = 0;
    long length = 0, str_length = 0;
    
    NSString *bundleIdString = nil;
    NSString *bundleVersionString = nil;
    NSData *bundleIdData = nil;
    NSData *hashData = nil;
    NSData *opaqueData = nil;
    //NSDate *expirationDate = nil;
    
    NSData *iapData = nil;
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
    if (type != V_ASN1_SET) {
        return nil;
    }
    
    while (ptr < end) {
        ASN1_INTEGER * integer;
        ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
        if (type != V_ASN1_SEQUENCE) {
            return nil;
        }
        
        const unsigned char * seq_end = ptr + length;
        long attr_type = 0;
        
        //long attr_version = 0;
        
        // Parse the attribute type (an INTEGER is expected)
        ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
        if (type != V_ASN1_INTEGER) {
            return nil;
        }
        integer = c2i_ASN1_INTEGER(NULL, &ptr, length);
        attr_type = ASN1_INTEGER_get(integer);
        ASN1_INTEGER_free(integer);
        
        // Parse the attribute version (an INTEGER is expected)
        ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
        if (type != V_ASN1_INTEGER) {
            return nil;
        }
        integer = c2i_ASN1_INTEGER(NULL, &ptr, length);
        
        //attr_version = ASN1_INTEGER_get(integer);
        ASN1_INTEGER_free(integer);
        
        // Check the attribute value (an OCTET STRING is expected)
        ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
        if (type != V_ASN1_OCTET_STRING) {
            return nil;
        }
        
        switch (attr_type) {
            case BUNDLE_ID:
                // Bundle identifier
                str_ptr = ptr;
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
                if (str_type == V_ASN1_UTF8STRING) {
                    // We store both the decoded string and the raw data for later
                    // The raw is data will be used when computing the GUID hash
                    bundleIdString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
                    bundleIdData = [[NSData alloc] initWithBytes:(const void *)ptr length:length];
                }
                break;
                
            case VERSION:
                // Bundle version
                str_ptr = ptr;
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
                if (str_type == V_ASN1_UTF8STRING) {
                    // We store the decoded string for later
                    bundleVersionString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
                }
                break;
                
            case OPAQUE_VALUE:
                // Opaque value
                opaqueData = [[NSData alloc] initWithBytes:(const void *)ptr length:length];
                break;
                
            case HASH:
                // Computed GUID (SHA-1 Hash)
                hashData = [[NSData alloc] initWithBytes:(const void *)ptr length:length];
                break;
                
            case INAPP_PURCHASE:
                // In-App purchases
                iapData = [[NSData alloc] initWithBytes:(const void *)ptr length:length];
                self.inAppPurchases = parseInAppPurchasesData(iapData);
                break;
                
            case EXPIRE_DATE:
                // Expiration date
                str_ptr = ptr;
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
                if (str_type == V_ASN1_IA5STRING) {
                    // The date is stored as a string that needs to be parsed
                    
                    //NSString *dateString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSASCIIStringEncoding];
                    //expirationDate = [formatter dateFromString:dateString];
                }
                break;
                
            default:
                break;
        }
        ptr += length;
    }
    
    if (bundleIdString == nil ||
        bundleVersionString == nil ||
        opaqueData == nil ||
        hashData == nil) {
        return nil;
    }
    
    // Check the bundle identifier
    if (![bundleIdString isEqualTo:@"com.yikuyiku.macos.TS-Analyzer"]) {
        return nil;
    }
    
    // Check the bundle version
    if (![bundleVersionString isEqualTo:@"1.2"]) {
        return nil;
    }
    
    CFDataRef guid_cf_data = copy_mac_address();
    if (guid_cf_data == nil) {
        return nil;
    }
    
    NSData *guidData = [NSData dataWithData:(__bridge NSData *) guid_cf_data];
    
    unsigned char hash[20];
    
    // Create a hashing context for computation
    SHA_CTX ctx;
    SHA1_Init(&ctx);
    SHA1_Update(&ctx, [guidData bytes], (size_t) [guidData length]);
    SHA1_Update(&ctx, [opaqueData bytes], (size_t) [opaqueData length]);
    SHA1_Update(&ctx, [bundleIdData bytes], (size_t) [bundleIdData length]);
    SHA1_Final(hash, &ctx);
    
    // Do the comparison
    NSData *computedHashData = [NSData dataWithBytes:hash length:20];
    if (![computedHashData isEqualToData:hashData]) {
        return nil;
    }
    
    return self;
}

CFDataRef copy_mac_address(void)
{
    kern_return_t             kernResult;
    mach_port_t               master_port;
    CFMutableDictionaryRef    matchingDict;
    io_iterator_t             iterator;
    io_object_t               service;
    CFDataRef                 macAddress = nil;
    
    kernResult = IOMasterPort(MACH_PORT_NULL, &master_port);
    if (kernResult != KERN_SUCCESS) {
        return nil;
    }
    
    matchingDict = IOBSDNameMatching(master_port, 0, "en0");
    if (!matchingDict) {
        return nil;
    }
    
    kernResult = IOServiceGetMatchingServices(master_port, matchingDict, &iterator);
    if (kernResult != KERN_SUCCESS) {
        return nil;
    }
    
    while((service = IOIteratorNext(iterator)) != 0) {
        io_object_t parentService;
        
        kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane,
                                                   &parentService);
        if (kernResult == KERN_SUCCESS) {
            if (macAddress) CFRelease(macAddress);
            
            macAddress = (CFDataRef) IORegistryEntryCreateCFProperty(parentService,
                                                                     CFSTR("IOMACAddress"), kCFAllocatorDefault, 0);
            IOObjectRelease(parentService);
        }
        
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator);
    
    return macAddress;
}


NSArray *parseInAppPurchasesData(NSData *inappData) {
    NSMutableArray *resultArray = [NSMutableArray array];
    int type = 0;
    int xclass = 0;
    long length = 0;
    
    NSUInteger dataLenght = [inappData length];
    const uint8_t *p = [inappData bytes];
    const uint8_t *end = p + dataLenght;
    
    while (p < end) {
        ASN1_get_object(&p, &length, &type, &xclass, end - p);
        
        const uint8_t *set_end = p + length;
        
        if(type != V_ASN1_SET) {
            break;
        }
        
        NSMutableDictionary *item = [[NSMutableDictionary alloc] initWithCapacity:6];
        
        while (p < set_end) {
            ASN1_get_object(&p, &length, &type, &xclass, set_end - p);
            if (type != V_ASN1_SEQUENCE) {
                break;
            }
            
            const uint8_t *seq_end = p + length;
            
            int attr_type = 0;
            //int attr_version = 0;
            
            // Attribute type
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            if (type == V_ASN1_INTEGER) {
                if(length == 1) {
                    attr_type = p[0];
                }
                else if(length == 2) {
                    attr_type = p[0] * 0x100 + p[1]
                    ;
                }
            }
            p += length;
            
            // Attribute version
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            if (type == V_ASN1_INTEGER && length == 1) {
                // clang analyser hit (wontfix at the moment, since the code might come in handy later)
                // But if someone has a convincing case throwing that out, I might do so, Roddi
                
                //attr_version = p[0];
            }
            p += length;
            
            // Only parse attributes we're interested in
            if ((attr_type > INAPP_ATTR_START && attr_type < INAPP_ATTR_END) || attr_type == INAPP_SUBEXP_DATE || attr_type == INAPP_WEBORDER || attr_type == INAPP_CANCEL_DATE) {
                NSString *key = nil;
                
                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                if (type == V_ASN1_OCTET_STRING) {
                    //NSData *data = [NSData dataWithBytes:p length:(NSUInteger)length];
                    
                    // Integers
                    if (attr_type == INAPP_QUANTITY || attr_type == INAPP_WEBORDER) {
                        int num_type = 0;
                        long num_length = 0;
                        const uint8_t *num_p = p;
                        ASN1_get_object(&num_p, &num_length, &num_type, &xclass, seq_end - num_p);
                        if (num_type == V_ASN1_INTEGER) {
                            NSUInteger quantity = 0;
                            if (num_length) {
                                quantity += num_p[0];
                                if (num_length > 1) {
                                    quantity += num_p[1] * 0x100;
                                    if (num_length > 2) {
                                        quantity += num_p[2] * 0x10000;
                                        if (num_length > 3) {
                                            quantity += num_p[3] * 0x1000000;
                                        }
                                    }
                                }
                            }
                            
                            NSNumber *num = [[NSNumber alloc] initWithUnsignedInteger:quantity];
                            if (attr_type == INAPP_QUANTITY) {
                                [item setObject:num forKey:@"kReceiptInAppQuantity"];
                            } else if (attr_type == INAPP_WEBORDER) {
                                [item setObject:num forKey:@"kReceiptInAppWebOrderLineItemID"];
                            }
                        }
                    }
                    
                    // Strings
                    if (attr_type == INAPP_PRODID ||
                        attr_type == INAPP_TRANSID ||
                        attr_type == INAPP_ORIGTRANSID ||
                        attr_type == INAPP_PURCHDATE ||
                        attr_type == INAPP_ORIGPURCHDATE ||
                        attr_type == INAPP_SUBEXP_DATE ||
                        attr_type == INAPP_CANCEL_DATE) {
                        
                        int str_type = 0;
                        long str_length = 0;
                        const uint8_t *str_p = p;
                        ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                        if (str_type == V_ASN1_UTF8STRING) {
                            switch (attr_type) {
                                case INAPP_PRODID:
                                    key = @"kReceiptInAppProductIdentifier";
                                    break;
                                case INAPP_TRANSID:
                                    key = @"kReceiptInAppTransactionIdentifier";
                                    break;
                                case INAPP_ORIGTRANSID:
                                    key = @"kReceiptInAppOriginalTransactionIdentifier";
                                    break;
                            }
                            
                            if (key) {
                                NSString *string = [[NSString alloc] initWithBytes:str_p
                                                                            length:(NSUInteger)str_length
                                                                          encoding:NSUTF8StringEncoding];
                                [item setObject:string forKey:key];
                            }
                        }
                        if (str_type == V_ASN1_IA5STRING) {
                            switch (attr_type) {
                                case INAPP_PURCHDATE:
                                    key = @"kReceiptInAppPurchaseDate";
                                    break;
                                case INAPP_ORIGPURCHDATE:
                                    key = @"kReceiptInAppOriginalPurchaseDate";
                                    break;
                                case INAPP_SUBEXP_DATE:
                                    key = @"kReceiptInAppSubscriptionExpirationDate";
                                    break;
                                case INAPP_CANCEL_DATE:
                                    key = @"kReceiptInAppCancellationDate";
                                    break;
                            }
                            
                            if (key) {
                                NSString *string = [[NSString alloc] initWithBytes:str_p
                                                                            length:(NSUInteger)str_length
                                                                          encoding:NSASCIIStringEncoding];
                                [item setObject:string forKey:key];
                            }
                        }
                    }
                }
                
                p += length;
            }
            
            // Skip any remaining fields in this SEQUENCE
            while (p < seq_end) {
                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                p += length;
            }
        }
        
        // Skip any remaining fields in this SET
        while (p < set_end) {
            ASN1_get_object(&p, &length, &type, &xclass, set_end - p);
            p += length;
        }
        
        [resultArray addObject:item];
    }
    return resultArray;
}

- (NSArray *) purchasedItems {
    return self.inAppPurchases;
}


@end

