//
//  JKXMPPTool.h
//  ChatDemo
//
//  Created by Joker on 15/7/19.
//  Copyright (c) 2015年 Mac. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JKXMPPTool : NSObject<XMPPStreamDelegate,UIAlertViewDelegate>

@property (nonatomic, strong) XMPPStream *xmppStream;
// 模块
@property (nonatomic, strong) XMPPAutoPing *xmppAutoPing;
@property (nonatomic, strong) XMPPReconnect *xmppReconnect;

@property (nonatomic, strong) XMPPRoster *xmppRoster;
@property (nonatomic, strong) XMPPRosterMemoryStorage *xmppRosterMemoryStorage;

@property (nonatomic, strong) XMPPMessageArchiving *xmppMessageArchiving;
@property (nonatomic, strong) XMPPMessageArchivingCoreDataStorage *xmppMessageArchivingCoreDataStorage;

@property (nonatomic, assign) BOOL  xmppNeedRegister;
@property (nonatomic, copy)   NSString *myPassword;

@property (nonatomic, strong) XMPPPresence *receivePresence;

+ (instancetype)sharedInstance;
- (void)loginWithJID:(XMPPJID *)JID andPassword:(NSString *)password;
- (void)registerWithJID:(XMPPJID *)JID andPassword:(NSString *)password;

- (void)addFriend:(XMPPJID *)aJID;

@end
