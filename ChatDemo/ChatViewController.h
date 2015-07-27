//
//  ChatViewController.h
//  ChatDemo
//
//  Created by Joker on 15/7/22.
//  Copyright (c) 2015年 Mac. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ChatViewController : UIViewController<UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate>

@property (nonatomic, strong) XMPPJID *chatJID;
/** 聊天记录*/
@property (nonatomic, strong) NSMutableArray *chatHistory;

@end
