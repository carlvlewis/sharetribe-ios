//
//  LoginViewController.m
//  Sharetribe
//
//  Created by Janne Käki on 6/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LoginViewController.h"

#import "SharetribeAPIClient.h"

@interface LoginViewController () <UITextFieldDelegate>

@end

@implementation LoginViewController

@synthesize usernameField;
@synthesize passwordField;
@synthesize loginButton;
@synthesize loginSpinner;

- (id)init
{
    self = [super initWithNibName:@"LoginViewController" bundle:nil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = kSharetribeThemeColor;
    
    [self.logoButton setShadowWithColor:[UIColor blackColor] opacity:0.9 radius:1 offset:CGSizeZero usingDefaultPath:NO];
    [self.ouishareLogoView setShadowWithOpacity:0.8 radius:1];
    
    usernameField.delegate = self;
    passwordField.delegate = self;
    
    usernameField.placeholder = NSLocalizedString(@"placeholder.username_or_email", @"");
    passwordField.placeholder = NSLocalizedString(@"placeholder.password", @"");
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidLogIn:) name:kNotificationForUserDidLogIn object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginConnectionDidFail:) name:kNotificationForLoginConnectionDidFail object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginAuthDidFail:) name:kNotificationForLoginAuthDidFail object:nil];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
    [self.view addGestureRecognizer:tap];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    loginSpinner.alpha = 0;
    loginButton.alpha = 1;
    
    // [usernameField becomeFirstResponder];
}

- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)hideKeyboard
{
    [self.usernameField resignFirstResponder];
    [self.passwordField resignFirstResponder];
}

- (IBAction)openSharetribeWebsite
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.sharetribe.com"]];
}

- (IBAction)openOuishareSignUp
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://share.ouisharefest.com/en/signup?no_fb=true"]];
}

- (IBAction)performLogin
{
    [[SharetribeAPIClient sharedClient] logInWithUsername:usernameField.text password:passwordField.text];
    
    [usernameField resignFirstResponder];
    [passwordField resignFirstResponder];
    
    [self setSpinnerVisible:YES];
}

- (void)userDidLogIn:(NSNotification *)notification
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loginConnectionDidFail:(NSNotification *)notification
{
    [self setSpinnerVisible:NO];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Problem Connecting to Sharetribe" message:@"Please try again in a minute, or check your network connectivity." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];  // LOCALIZE
    [alert show];
}

- (void)loginAuthDidFail:(NSNotification *)notification
{
    [self setSpinnerVisible:NO];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Wrong Username or Password" message:@"Please try again, or check our web page for assistance." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];  // LOCALIZE
    [alert show];
}

- (void)setSpinnerVisible:(BOOL)visible
{
    [UIView animateWithDuration:0.3 animations:^{
        loginButton.alpha = (visible) ? 0 : 1;
        loginSpinner.alpha = (visible) ? 1 : 0;
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == usernameField) {
        [passwordField becomeFirstResponder];
    } else {
        [self performLogin];
    }
    return YES;
}

@end
