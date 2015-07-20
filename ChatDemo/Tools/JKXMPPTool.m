//
//  JKXMPPTool.m
//  ChatDemo
//
//  Created by Joker on 15/7/19.
//  Copyright (c) 2015年 Mac. All rights reserved.
//

#import "JKXMPPTool.h"

@implementation JKXMPPTool

static JKXMPPTool *_instance;
+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [JKXMPPTool new];
    });
    
    return _instance;
}

- (XMPPStream *)xmppStream
{
    if (!_xmppStream) {
        _xmppStream = [[XMPPStream alloc] init];
        
        //socket 连接的时候 要知道host port 然后connect
        [self.xmppStream setHostName:kXMPP_HOST];
        [self.xmppStream setHostPort:kXMPP_PORT];
        //为什么是addDelegate? 因为xmppFramework 大量使用了多播代理multicast-delegate ,代理一般是1对1的，但是这个多播代理是一对多得，而且可以在任意时候添加或者删除
        [self.xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
        
        //添加功能模块
        //1.autoPing 发送的时一个stream:ping 对方如果想表示自己是活跃的，应该返回一个pong
        _xmppAutoPing = [[XMPPAutoPing alloc] init];
        //所有的Module模块，都要激活active
        [_xmppAutoPing activate:self.xmppStream];
        
        //autoPing由于它会定时发送ping,要求对方返回pong,因此这个时间我们需要设置
        [_xmppAutoPing setPingInterval:1000];
        //不仅仅是服务器来得响应;如果是普通的用户，一样会响应
        [_xmppAutoPing setRespondsToQueries:YES];
        //这个过程是C---->S  ;观察 S--->C(需要在服务器设置）
        
        //2.autoReconnect 自动重连，当我们被断开了，自动重新连接上去，并且将上一次的信息自动加上去
        _xmppReconnect = [[XMPPReconnect alloc] init];
        [_xmppReconnect activate:self.xmppStream];
        [_xmppReconnect setAutoReconnect:YES];
    }
    return _xmppStream;
}

- (void)loginWithJID:(XMPPJID *)JID andPassword:(NSString *)password
{
    // 1.建立TCP连接
    // 2.把我自己的jid与这个TCP连接绑定起来
    // 3.认证（登录：验证jid与密码是否正确，加密方式 不可能以明文发送）--（出席：怎样告诉服务器我上线，以及我得上线状态
    //这句话会在xmppStream以后发送XML的时候加上 <message from="JID">
    [self.xmppStream setMyJID:JID];
    self.myPassword = password;
    self.xmppNeedRegister = NO;
    [self.xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:nil];
}

//注册方法里没有调用auth方法
- (void)registerWithJID:(XMPPJID *)JID andPassword:(NSString *)password
{
    [self.xmppStream setMyJID:JID];
    self.myPassword = password;
    self.xmppNeedRegister = YES;
    [self.xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:nil];
}

- (void)goOnline
{
    // 发送一个<presence/> 默认值avaliable 在线 是指服务器收到空的presence 会认为是这个
    XMPPPresence *presence = [XMPPPresence presence];
    [presence addChild:[DDXMLNode elementWithName:@"status" stringValue:@"我现在很忙"]];
    [presence addChild:[DDXMLNode elementWithName:@"show" stringValue:@"xa"]];
    
    [self.xmppStream sendElement:presence];
}

#pragma mark ===== XMPPStream delegate =======
//socket 连接建立成功
- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
    NSLog(@"%s",__func__);
}

//这个是xml流初始化成功
- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    NSLog(@"%s",__func__);
    if (self.xmppNeedRegister) {
        BOOL result = [self.xmppStream registerWithPassword:self.myPassword error:nil];
        NSNumber *number = [NSNumber numberWithBool:result];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kREGIST_RESULT object:number];
        
    } else {
        [self.xmppStream authenticateWithPassword:self.myPassword error:nil];
    }
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    NSLog(@"%s",__func__);
}

//登录失败
- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(DDXMLElement *)error
{
    NSLog(@"%s",__func__);
}

//登录成功
- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    NSLog(@"%s",__func__);
    
    [self goOnline];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kLOGIN_SUCCESS object:nil];
}


@end
