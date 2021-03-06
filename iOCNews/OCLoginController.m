//
//  OCLoginController.m
//  iOCNews
//

/************************************************************************
 
 Copyright 2013 Peter Hedlund peter.hedlund@me.com
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 *************************************************************************/

#import "OCLoginController.h"
#import "OCAPIClient.h"
#import "KeychainItemWrapper.h"
#import "UILabel+VerticalAlignment.h"

static const NSString *rootPath = @"index.php/apps/news/api/v1-2/";

@interface OCLoginController ()

@end

@implementation OCLoginController

@synthesize keychain;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    NSString *version = @"Version ";
    version = [version stringByAppendingString:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
	self.versionLabel.text = version;
    self.statusLabel.textVerticalAlignment = UITextVerticalAlignmentTop;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.serverTextField.text = [prefs stringForKey:@"Server"];
    self.usernameTextField.text = [self.keychain objectForKey:(__bridge id)(kSecAttrAccount)];
    self.passwordTextField.text = [self.keychain objectForKey:(__bridge id)(kSecValueData)];
    
    NSString *status;
    if ([[OCAPIClient sharedClient] networkReachabilityStatus] > 0) {
        status = [NSString stringWithFormat:@"Connected to an ownCloud News server at \"%@\".", [[NSUserDefaults standardUserDefaults] stringForKey:@"Server"]];
    } else {
        status = @"Currently not connected to an ownCloud News server";
    }
    self.statusLabel.text = status;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)doDone:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        [tableView deselectRowAtIndexPath:indexPath animated:true];
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        if (![self.serverTextField.text isEqualToString:[prefs stringForKey:@"Server"]] ||
            ![self.usernameTextField.text isEqualToString:[self.keychain objectForKey:(__bridge id)(kSecAttrAccount)]] ||
            ![self.passwordTextField.text isEqualToString:[self.keychain objectForKey:(__bridge id)(kSecValueData)]]) {
            
            [self.connectionActivityIndicator startAnimating];
            AFHTTPClient *client = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.serverTextField.text, rootPath]]];
            [client setAuthorizationHeaderWithUsername:self.usernameTextField.text password:self.passwordTextField.text];
            
            NSMutableURLRequest *request = [client requestWithMethod:@"GET" path:@"version" parameters:nil];
            
            AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                
                NSLog(@"Version: %@", JSON);
                NSDictionary *jsonDict = (NSDictionary *) JSON;
                NSString *version = [jsonDict valueForKey:@"version"];
                
                [prefs setObject:self.serverTextField.text forKey:@"Server"];
                [self.keychain setObject:self.usernameTextField.text forKey:(__bridge id)(kSecAttrAccount)];
                [self.keychain setObject:self.passwordTextField.text forKey:(__bridge id)(kSecValueData)];
                [OCAPIClient setSharedClient:nil];
                int status = [[OCAPIClient sharedClient] networkReachabilityStatus];
                NSLog(@"Server status: %i", status);
                self.statusLabel.text = [NSString stringWithFormat:@"Connected to an ownCloud News server at \"%@\" running version %@.", self.serverTextField.text, version];
                
                [self.connectionActivityIndicator stopAnimating];
                
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                self.statusLabel.text = @"Failed to connect to a server. Check your settings";
                [self.connectionActivityIndicator stopAnimating];
            }];
            [client enqueueHTTPRequestOperation:operation];
        }
    }
}

- (KeychainItemWrapper *)keychain {
    if (!keychain) {
        keychain = [[KeychainItemWrapper alloc] initWithIdentifier:@"iOCNews" accessGroup:nil];
        [keychain setObject:(__bridge id)(kSecAttrAccessibleWhenUnlocked) forKey:(__bridge id)(kSecAttrAccessible)];
    }
    return keychain;
}

@end
