//
//  ReceiptValidation.h
//  HTTPLook
//
//  Created by ChenGang on 2016/10/20.
//  Copyright © 2016年 ChenGang. All rights reserved.
//

#ifndef ReceiptValidation_h
#define ReceiptValidation_h

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

#include <openssl/bio.h>
#include <openssl/pkcs7.h>
#include <openssl/x509.h>
#include <openssl/objects.h>

@interface ReceiptValidation : NSObject
@property (strong, nonatomic) NSURL *receiptURL ;
@property (nonatomic) Boolean valid;
@property (strong, nonatomic) NSArray *inAppPurchases;

- (ReceiptValidation *)init;
- (NSArray *) purchasedItems;

@end

#endif /* ReceiptValidation_h */
