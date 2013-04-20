//
//  CreateListingViewController.m
//  Sharetribe
//
//  Created by Janne Käki on 2/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CreateListingViewController.h"

#import "Location.h"
#import "SharetribeAPIClient.h"
#import "User.h"
#import "GTMNSString+HTML.h"
#import <QuartzCore/QuartzCore.h>

@interface CreateListingViewController () {
    BOOL convertingImage;
    BOOL submissionWaitingForImage;
    BOOL preserveFormItemsOnNextAppearance;
}
- (void)dismissDatePicker;
@end

@interface CustomTextField : UITextField
@end

@implementation CreateListingViewController

@synthesize listing;
@synthesize formItems;

@synthesize table;
@synthesize footer;

@synthesize submitButton;
@synthesize cancelButton;
@synthesize uploadTitleView;
@synthesize uploadProgressLabel;
@synthesize uploadProgressView;
@synthesize uploadSpinner;

@synthesize datePicker;

@synthesize activeTextInput;
@synthesize formItemBeingEdited;

- (id)init
{
    self = [super init];
    if (self) {
                
        self.view.backgroundColor = kSharetribeBrownColor;
                
        self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, self.view.height) style:UITableViewStylePlain];
        table.dataSource = self;
        table.delegate = self;
        table.backgroundColor = [UIColor clearColor];
        table.separatorColor = kSharetribeBrownColor;
        table.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        
        self.submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
        submitButton.frame = CGRectMake(10, 24, 300, 40);
        submitButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [submitButton setTitle:NSLocalizedString(@"button.post", @"") forState:UIControlStateNormal];
        [submitButton setBackgroundImage:[[UIImage imageNamed:@"dark-brown.png"] stretchableImageWithLeftCapWidth:5 topCapHeight:5] forState:UIControlStateNormal];
        [submitButton addTarget:self action:@selector(postButtonPressed:) forControlEvents:UIControlEventTouchUpInside],
        
        self.uploadSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        uploadSpinner.frame = CGRectMake((submitButton.width-uploadSpinner.width)/2, 10, uploadSpinner.width, uploadSpinner.height);
        uploadSpinner.hidesWhenStopped = YES;
        [submitButton addSubview:uploadSpinner];
        
        self.footer = [[UIView alloc] init];
        footer.frame = CGRectMake(0, 0, 320, 110);
        footer.backgroundColor = kSharetribeBrownColor;
        [footer addSubview:submitButton];
        
        [self.view addSubview:table];
        
        self.datePicker = [[UIDatePicker alloc] init];
        datePicker.frame = CGRectMake(0, self.view.height, 320, 216);
        [datePicker addTarget:self action:@selector(datePickerValueChanged:) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:datePicker];
        
        rowSpacing = 18;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadDidProgress:) name:kNotificationForUploadDidProgress object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didPostListing:) name:kNotificationForDidPostListing object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFailToPostListing:) name:kNotificationForFailedToPostListing object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!preserveFormItemsOnNextAppearance) {
        
        if (listing == nil) {
            
            // So, creating a brand new listing:
            self.listing = [[Listing alloc] init];
            listing.type = kListingTypeOffer;
            
            User *currentUser = [User currentUser];
            Location *location;
            
            if (currentUser.location != nil) {
                location = currentUser.location;
            } else if ([Location currentLocation] != nil) {
                location = [Location currentLocation];
            } else {
                location = [[Location alloc] initWithLatitude:60.156714 longitude:24.883003 address:nil];  // OBS! maybe the community's default location instead?
            }
            
            listing.location = [location copy];
            listing.destination = [location copy];
            
            [table setContentOffset:CGPointZero animated:NO];
            
            self.navigationItem.titleView = nil;
            
            convertingImage = NO;
            submissionWaitingForImage = NO;
            
            submitButton.enabled = YES;
            [submitButton setTitle:NSLocalizedString(@"button.post", @"") forState:UIControlStateNormal];
            [uploadSpinner stopAnimating];
                        
            self.title = NSLocalizedString(@"tabs.new_listing", @"");
            
        } else {
            
            // So, editing an existing listing:
            [self reloadFormItems];
            
            table.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.width, 30)];
            
            self.title = NSLocalizedString(@"title.edit_listing", @"");
        }
        
        self.cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
        self.navigationItem.leftBarButtonItem = cancelButton;
        
        self.navigationController.navigationBar.tintColor = kSharetribeDarkBrownColor;
    }
    
    preserveFormItemsOnNextAppearance = NO;
    
    [table reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)uploadDidProgress:(NSNotification *)notification
{
    id progress = notification.object;
    if ([progress respondsToSelector:@selector(floatValue)]) {
        uploadProgressView.progress = [progress floatValue];
    }
}

- (void)didPostListing:(NSNotification *)notification
{    
    self.listing = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"alert.listing.posted", @"") message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"button.ok", @"") otherButtonTitles:nil];
    [alert show];
}

- (void)didFailToPostListing:(NSNotification *)notification
{
    submitButton.enabled = YES;
    [submitButton setTitle:NSLocalizedString(@"button.post", @"") forState:UIControlStateNormal];
    [uploadSpinner stopAnimating];
    
    self.navigationItem.titleView = nil;
    
    NSMutableString *message = [NSMutableString stringWithString:NSLocalizedString(@"alert.listing.failed_to_post", @"")];
    if ([notification.object isKindOfClass:NSArray.class]) {
        for (id object in notification.object) {
            [message appendFormat:@"\n\n%@", object];
        }
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"alert.title.error", @"") message:message delegate:self cancelButtonTitle:NSLocalizedString(@"button.ok", @"") otherButtonTitles:nil];
    [alert show];
}

- (void)reloadFormItems
{
    NSString *propertyListName = [NSString stringWithFormat:@"form-%@-%@", listing.category, listing.type];
    self.formItems = [FormItem formItemsFromDataArray:[NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:propertyListName ofType:@"plist"]]];
    
    [table reloadData];
    
    table.tableFooterView = footer;
    
    submitButton.hidden = (listing.category == nil);
}

- (void)cancel
{
    self.listing = nil;
    self.formItems = nil;
    table.tableFooterView = nil;
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

#define kCellTitleLabelTag      1000
#define kCellSubtitleLabelTag   1001
#define kCellHelpButtonTag      1002

#define kCellTextFieldTag       1101
#define kCellTextViewTag        1102

#define kCellPhotoViewTag       1200
#define kCellPhotoButtonTag     1201

#define kCellChoiceViewTagBase  1300
#define kChoiceCellLabelTag     3000
#define kChoiceCellCheckmarkTag 3001

#define kMaxAlternativeCount    10

#define kCellMapViewTag         1500

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return formItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FormItem *formItem = [formItems objectAtIndex:indexPath.row];
    NSInteger rowHeight = [self tableView:tableView heightForRowAtIndexPath:indexPath];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:formItem.typeAsString];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:formItem.typeAsString];
        cell.contentView.backgroundColor = kSharetribeBrownColor;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.frame = CGRectMake(10, 0, 300, 20);
        titleLabel.font = [UIFont boldSystemFontOfSize:15];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.tag = kCellTitleLabelTag;
        [cell addSubview:titleLabel];

        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.frame = CGRectMake(10, 3, 300, 16);
        subtitleLabel.font = [UIFont boldSystemFontOfSize:12];
        subtitleLabel.textAlignment = NSTextAlignmentLeft;
        subtitleLabel.backgroundColor = [UIColor clearColor];
        subtitleLabel.tag = kCellSubtitleLabelTag;
        [cell addSubview:subtitleLabel];
        
        UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeCustom];
        NSString *helpButtonTitle = NSLocalizedString(@"listing.explanation", @"");
        [helpButton setTitle:helpButtonTitle forState:UIControlStateNormal];
        [helpButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
        [helpButton setTitleShadowColor:kSharetribeLightBrownColor forState:UIControlStateNormal];
        helpButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        helpButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
        helpButton.width = [helpButtonTitle sizeWithFont:helpButton.titleLabel.font].width;
        helpButton.x = 320 - 10 - helpButton.width;
        helpButton.y = 0;
        helpButton.height = 24;
        helpButton.tag = kCellHelpButtonTag;
        [helpButton addTarget:self action:@selector(showItemHelp:) forControlEvents:UIControlEventTouchUpInside];
        [cell addSubview:helpButton];
        
        if (formItem.type == FormItemTypeTextField) {
            
            UITextField *textField = [[CustomTextField alloc] init];
            textField.font = [UIFont systemFontOfSize:15];
            textField.tag = kCellTextFieldTag;
            textField.backgroundColor = kSharetribeLightBrownColor;
            textField.keyboardAppearance = UIKeyboardAppearanceAlert;
            textField.returnKeyType = UIReturnKeyDone;
            textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            textField.delegate = self;
            [cell addSubview:textField];
            
        } else if (formItem.type == FormItemTypeTextArea) {
            
            UITextView *textView = [[UITextView alloc] init];
            textView.font = [UIFont systemFontOfSize:15];
            textView.tag = kCellTextViewTag;
            textView.backgroundColor = kSharetribeLightBrownColor;
            textView.keyboardAppearance = UIKeyboardAppearanceAlert;
            textView.delegate = self;
            [cell addSubview:textView];
            
        } else if (formItem.type == FormItemTypePhoto) {
            
            UIImageView *photoView = [[UIImageView alloc] init];
            photoView.tag = kCellPhotoViewTag;
            [cell addSubview:photoView];
            
            UIButton *photoButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [photoButton setTitleColor:kSharetribeDarkBrownColor forState:UIControlStateNormal];
            [photoButton setTitleColor:kSharetribeBrownColor forState:UIControlStateHighlighted];
            [photoButton setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
            photoButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            photoButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
            photoButton.tag = kCellPhotoButtonTag;
            [photoButton addTarget:self action:@selector(photoButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            [cell addSubview:photoButton];
            
        } else if (formItem.type == FormItemTypeLocation) {
            
            UITextField *textField = [[CustomTextField alloc] init];
            textField.placeholder = NSLocalizedString(@"placeholder.address", @"");
            textField.frame = CGRectMake(10, 30, 300, 40);
            textField.font = [UIFont systemFontOfSize:15];
            textField.tag = kCellTextFieldTag;
            textField.backgroundColor = kSharetribeLightBrownColor;
            textField.keyboardAppearance = UIKeyboardAppearanceAlert;
            textField.returnKeyType = UIReturnKeyDone;
            textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            textField.layer.cornerRadius = 8;
            textField.delegate = self;
            [cell addSubview:textField];
            
            MKMapView *mapView = [[MKMapView alloc] init];
            mapView.mapType = MKMapTypeStandard;
            mapView.delegate = self;
            mapView.userInteractionEnabled = NO;
            mapView.showsUserLocation = NO;
            mapView.layer.borderWidth = 1;
            mapView.layer.borderColor = kSharetribeLightBrownColor.CGColor;
            mapView.layer.cornerRadius = 8;
            mapView.alpha = 1;
            mapView.tag = kCellMapViewTag;
            mapView.frame = CGRectMake(10, 80, 300, rowHeight-80-rowSpacing);
            [cell addSubview:mapView];
            
            UIButton *mapButton = [UIButton buttonWithType:UIButtonTypeCustom];
            mapButton.frame = mapView.frame;
            [mapButton addTarget:self action:@selector(mapPressed:) forControlEvents:UIControlEventTouchUpInside];
            [cell addSubview:mapButton];
            
//            Location *location = [listing valueForKey:formItem.mapsTo];
//            if (location != nil) {
//                textField.text = location.address;
//                [mapView addAnnotation:location];
//            }
        }
    }
    
    UILabel *titleLabel = (UILabel *) [cell viewWithTag:kCellTitleLabelTag];
    titleLabel.text = formItem.localizedTitle;
    if (formItem.mandatory) {
        titleLabel.text = [NSString stringWithFormat:@"%@*", titleLabel.text];
    }
    
    UILabel *subtitleLabel = (UILabel *) [cell viewWithTag:kCellSubtitleLabelTag];
    subtitleLabel.text = (formItem.subtitleKey != nil) ? formItem.localizedSubtitle : nil;
    subtitleLabel.x = titleLabel.x + [titleLabel.text sizeWithFont:titleLabel.font].width + 5;
    
    UIButton *helpButton = (UIButton *) [cell viewWithTag:kCellHelpButtonTag];
    helpButton.hidden = !(formItem.providesExplanation);

    if (formItem.type == FormItemTypeTextField) {
        
        UITextField *textField = (UITextField *) [cell viewWithTag:kCellTextFieldTag];
        textField.frame = CGRectMake(10, 30, 300, 40);
        id value = [listing valueForKey:formItem.mapsTo];
        if ([value isKindOfClass:NSArray.class] && formItem.listSeparator != nil) {
            value = [value componentsJoinedByString:formItem.listSeparator];
        }
        textField.text = value;
        textField.autocapitalizationType = formItem.autocapitalizationType;
        
    } else if (formItem.type == FormItemTypeTextArea) {
        
        UITextView *textView = (UITextView *) [cell viewWithTag:kCellTextViewTag];
        textView.frame = CGRectMake(10, 30, 300, rowHeight-32-rowSpacing);
        textView.text = [listing valueForKey:formItem.mapsTo];
        textView.autocapitalizationType = formItem.autocapitalizationType;
        
    } else if (formItem.type == FormItemTypeChoice || formItem.type == FormItemTypeDate) {
        
        id chosenAlternative = [listing valueForKey:formItem.mapsTo];
        
        if (formItem.type == FormItemTypeChoice) {
            if (chosenAlternative == nil) {
                chosenAlternative = formItem.alternatives[0];
                [listing setValue:chosenAlternative forKey:formItem.mapsTo];
            }
        }
        
        for (int i = 0; i < kMaxAlternativeCount; i++) {
            UIView *choiceView = [cell viewWithTag:kCellChoiceViewTagBase+i];
            if (i >= formItem.alternatives.count) {
                if (choiceView != nil) {
                    choiceView.hidden = YES;
                }
            } else {
                if (choiceView == nil) {
                    choiceView = [[UIView alloc] init];
                    choiceView.frame = CGRectMake(10, 30 + 45 * i, 300, 40);
                    choiceView.layer.cornerRadius = 8;
                    choiceView.tag = kCellChoiceViewTagBase+i;
                    [cell addSubview:choiceView];
                    
                    UILabel *choiceLabel = [[UILabel alloc] init];
                    choiceLabel.frame = CGRectMake(42, 0, 220, 40);
                    choiceLabel.font = [UIFont boldSystemFontOfSize:15];
                    choiceLabel.backgroundColor = [UIColor clearColor];
                    choiceLabel.tag = kChoiceCellLabelTag;
                    [choiceView addSubview:choiceLabel];
                    
                    UIImageView *choiceCheckmark = [[UIImageView alloc] init];
                    choiceCheckmark.frame = CGRectMake(15, 14, 15, 12);
                    choiceCheckmark.tag = kChoiceCellCheckmarkTag;
                    [choiceView addSubview:choiceCheckmark];
                    
                    UIButton *choiceButton = [UIButton buttonWithType:UIButtonTypeCustom];
                    choiceButton.frame = CGRectMake(0, 0, choiceView.width, choiceView.height);
                    [choiceButton addTarget:self action:@selector(choiceButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
                    choiceButton.tag = i;
                    [choiceView addSubview:choiceButton];
                }
                choiceView.hidden = NO;
                
                UILabel *choiceLabel = (UILabel *) [choiceView viewWithTag:kChoiceCellLabelTag];
                id alternative = [formItem.alternatives objectAtIndex:i];
                if (formItem.type == FormItemTypeDate && [alternative isKindOfClass:NSDate.class]) {
                    if (formItem.includeTime) {
                        choiceLabel.text = [alternative dateAndTimeString];
                    } else {
                        choiceLabel.text = [alternative dateString];
                    }
                    // we don't localize timestamps the crude way, no
                } else {
                    choiceLabel.text = [formItem localizedTitleForAlternative:alternative];
                }
                choiceLabel.textColor = [UIColor blackColor];
                if (formItem.type == FormItemTypeDate && [alternative isKindOfClass:NSDate.class]) {
                    choiceLabel.textColor = kSharetribeDarkBrownColor;
                }
                
                UIImageView *choiceCheckmark = (UIImageView *) [choiceView viewWithTag:kChoiceCellCheckmarkTag];
                
                if (formItem.type == FormItemTypeDate && formItem.alternatives.count == 1) {
                    choiceCheckmark.image = nil;
                    choiceLabel.x = 16; 
                } else {
                    choiceCheckmark.image = [UIImage imageNamed:@"checkmark"];
                    choiceLabel.x = 42;
                }
                
                [UIView beginAnimations:nil context:NULL];
                if ([chosenAlternative isEqual:alternative] ||
                        (chosenAlternative == nil && [alternative isEqual:kValidForTheTimeBeing]) ||
                        choiceCheckmark.image == nil) {
                    choiceView.backgroundColor = kSharetribeLightBrownColor;
                    choiceCheckmark.alpha = 1;
                } else {
                    choiceView.backgroundColor = kSharetribeLightishBrownColor;
                    choiceCheckmark.alpha = 0;
                }
                
                [UIView commitAnimations];
            }
        }
    
    } else if (formItem.type == FormItemTypePhoto) {
        
        UIImageView *photoView = (UIImageView *) [cell viewWithTag:kCellPhotoViewTag];
        UIButton *photoButton = (UIButton *) [cell viewWithTag:kCellPhotoButtonTag];
        
        if (listing.image != nil) {
            
            if (photoView.image != listing.image) {
                photoView.image = listing.image;
                photoView.backgroundColor = [UIColor clearColor];
                CGFloat photoWidth = photoView.image.size.width;
                CGFloat photoHeight = photoView.image.size.height;
                if (photoWidth >= photoHeight) {
                    photoView.x = 10;
                    photoView.width = 300;
                } else {
                    photoView.x = 50;
                    photoView.width = 220;
                }
                photoView.y = 30;
                photoView.height = photoView.width * (photoHeight/photoWidth);
            }
            [photoButton setTitle:nil forState:UIControlStateNormal];
            
            photoView.layer.cornerRadius = 0;
            photoView.layer.borderColor = kSharetribeDarkBrownColor.CGColor;
            photoView.layer.borderWidth = 1;
            
        } else {
            
            photoView.image = nil;
            photoView.backgroundColor = kSharetribeLightBrownColor;
            photoView.frame = CGRectMake(10, 30, 300, rowHeight - 30 - rowSpacing);
            [photoButton setTitle:NSLocalizedString(@"listing.image.add", @"") forState:UIControlStateNormal];
            
            photoView.layer.cornerRadius = 8;            
            photoView.layer.borderColor = [UIColor clearColor].CGColor;
            photoView.layer.borderWidth = 0;
        }
        
        photoButton.frame = photoView.frame;
        
    } else if (formItem.type == FormItemTypeLocation) {
        
        UITextField *textField = (UITextField *) [cell viewWithTag:kCellTextFieldTag];
        MKMapView *mapView = (MKMapView *) [cell viewWithTag:kCellMapViewTag];
        
        [mapView removeAnnotations:mapView.annotations];
        
        Location *location = [listing valueForKey:formItem.mapsTo];
        if (location != nil) {
            
            NSLog(@"textfield: %@, address: %@", textField, location.address);
            
            textField.text = location.address;
            
            [mapView addAnnotation:location];
            
            if (mapView.centerCoordinate.latitude != location.coordinate.latitude ||
                mapView.centerCoordinate.longitude != location.coordinate.longitude) {
                
                [mapView setRegion:MKCoordinateRegionMakeWithDistance(location.coordinate, 2000, 4000) animated:NO];
            }
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FormItem *formItem = [formItems objectAtIndex:indexPath.row];
    NSInteger rowHeight = 0;
    
    if (formItem.type == FormItemTypeTextField) {
        
        rowHeight = 74;
        
    } else if (formItem.type == FormItemTypeTextArea) {
    
        rowHeight = 175;
        
    } else if (formItem.type == FormItemTypePhoto) {
        
        if (listing.image != nil && [listing.image isKindOfClass:UIImage.class]) {
            CGFloat photoWidth = listing.image.size.width;
            CGFloat photoHeight = listing.image.size.height;
            int photoViewWidth = (photoWidth >= photoHeight) ? 300 : 220;
            rowHeight = 30 + photoViewWidth * (photoHeight / photoWidth);
        } else {
            rowHeight = 100;
        }
        
    } else if (formItem.type == FormItemTypeChoice) {
        
        rowHeight = 30 + formItem.alternatives.count * 45;
    
    } else if (formItem.type == FormItemTypeLocation) {
        
        rowHeight = 50 + 175;
    
    } else if (formItem.type == FormItemTypeDate) {
        
        rowHeight = 30 + 45;
        if (formItem.allowsUndefined) {
            rowHeight += 45;
        }
    }
    
    return rowHeight + rowSpacing;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (activeTextInput != nil) {
        [activeTextInput resignFirstResponder];
    }
    
    if (datePicker.y < self.view.height) {
        [self dismissDatePicker];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{    
}

#pragma mark - UITextFieldDelegate and UITextViewDelegate

- (void)textInputViewDidBeginEditing:(UIView *)textInputView
{
    self.activeTextInput = textInputView;
    
    [UIView beginAnimations:nil context:NULL];
    table.height = self.view.height-216;
    [UIView commitAnimations];
    
    NSIndexPath *path = [table indexPathForRowAtPoint:[table convertPoint:CGPointZero fromView:textInputView]];
    [table scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"button.ok", @"") style:UIBarButtonItemStyleBordered target:textInputView action:@selector(resignFirstResponder)];
}

- (void)textInputViewDidEndEditing:(UIView *)textInputView
{
    if (textInputView == activeTextInput) {
        self.activeTextInput = nil;
        table.height = self.view.height;
        
        self.navigationItem.leftBarButtonItem = cancelButton;
        self.navigationItem.rightBarButtonItem = nil;
    }
    
    NSIndexPath *path = [table indexPathForRowAtPoint:[table convertPoint:CGPointZero fromView:textInputView]];
    FormItem *formItem = [formItems objectAtIndex:path.row];
    if (formItem.type == FormItemTypeLocation) {
        Location *location = [listing valueForKey:formItem.mapsTo];
        location.address = [(id) textInputView text];
        location.addressIsAutomatic = NO;
    } else {
        id value = [(id) textInputView text];
        if (formItem.listSeparator != nil && [value isKindOfClass:NSString.class]) {
            value = [value stringByReplacingOccurrencesOfString:@"  " withString:@" "];
            value = [value stringByReplacingOccurrencesOfString:[formItem.listSeparator stringByAppendingString:@" "] withString:formItem.listSeparator];
            value = [value componentsSeparatedByString:formItem.listSeparator];
        }
        [listing setValue:value forKey:formItem.mapsTo];
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self textInputViewDidBeginEditing:textField];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self textInputViewDidEndEditing:textField];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [self textInputViewDidBeginEditing:textView];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [self textInputViewDidEndEditing:textView];
}

#pragma mark - UIAlertViewDelegate

#define kAlertViewTagForCanceling      1000

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kAlertViewTagForCanceling) {
        if (buttonIndex != alertView.cancelButtonIndex) {
            [self cancel];
        }
    }
}

#pragma mark - UIActionSheetDelegate

#define kActionSheetTagForAddingPhoto  1000

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet.tag == kActionSheetTagForAddingPhoto) {
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
            if (buttonIndex == 0) {
                imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
                imagePicker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
            } else {
                imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            }
            imagePicker.allowsEditing = NO;
            imagePicker.delegate = self;
            [self presentViewController:imagePicker animated:YES completion:nil];
            preserveFormItemsOnNextAppearance = YES;
        }
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo
{
    listing.image = image;
    [table reloadData];
    
    if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, NULL);
    }
    
    [self performSelectorInBackground:@selector(convertImageToData) withObject:nil];
    
    [picker dismissModalViewControllerAnimated:YES];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)convertImageToData
{
    convertingImage = YES;
    listing.imageData = UIImageJPEGRepresentation(listing.image, 0.9);
    convertingImage = NO;
    [self performSelectorOnMainThread:@selector(imageConversionFinished) withObject:nil waitUntilDone:NO];
}

- (void)imageConversionFinished
{
    if (submissionWaitingForImage) {
        submissionWaitingForImage = NO;
        [self postButtonPressed:nil];
    }
}

#pragma mark - ListingTypeSelectionDelegate

- (void)listingTypeSelected:(NSString *)type
{
    listing.type = type;
    [self reloadFormItems];
}

- (void)listingCategorySelected:(NSString *)category
{
    listing.category = category;
    [self reloadFormItems];
}

#pragma mark - LocationPickerDelegate

- (void)locationPicker:(LocationPickerViewController *)picker pickedCoordinate:(CLLocationCoordinate2D)coordinate withAddress:(NSString *)address
{
    Location *location = [[Location alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude address:nil];
    
    Location *oldLocation = [listing valueForKey:formItemBeingEdited.mapsTo];
    if (oldLocation.address.length > 0 && !oldLocation.addressIsAutomatic) {
        NSLog(@"kept old address: %@", oldLocation.address);
        location.address = oldLocation.address;
    } else {
        location.address = address;
        location.addressIsAutomatic = YES;
    }
    
    [listing setValue:location forKey:formItemBeingEdited.mapsTo];
    [table reloadData];
}

- (void)locationPickedDidCancel:(LocationPickerViewController *)picker
{
}

#pragma mark -

- (IBAction)showItemHelp:(UIButton *)sender
{
    NSIndexPath *path = [table indexPathForRowAtPoint:[table convertPoint:CGPointZero fromView:sender]];    
    FormItem *formItem = [formItems objectAtIndex:path.row];
    NSString *itemHelp = formItem.localizedExplanation;
    itemHelp = [itemHelp stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
    itemHelp = [itemHelp gtm_stringByUnescapingFromHTML];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:formItem.localizedTitle message:itemHelp delegate:self cancelButtonTitle:NSLocalizedString(@"button.ok", @"") otherButtonTitles:nil];
    [alert show];
}

- (IBAction)photoButtonPressed:(UIButton *)sender
{
    UIActionSheet *actionSheetForAddingPhoto = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:NSLocalizedString(@"button.cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"button.take_new_photo", @""), NSLocalizedString(@"button.choose_photo_from_library", @""), nil];
    actionSheetForAddingPhoto.tag = kActionSheetTagForAddingPhoto;
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [actionSheetForAddingPhoto showInView:self.view];
    } else {
        [self actionSheet:actionSheetForAddingPhoto clickedButtonAtIndex:1];
    }
}

- (IBAction)choiceButtonPressed:(UIButton *)sender
{
    NSIndexPath *path = [table indexPathForRowAtPoint:[table convertPoint:CGPointZero fromView:sender]];    
    FormItem *formItem = formItems[path.row];
    id value = formItem.alternatives[sender.tag];
    
    if (formItem.type == FormItemTypeDate) {
        
        if ([value isKindOfClass:NSDate.class]) {
            
            datePicker.minimumDate = [NSDate date];
            datePicker.datePickerMode = (formItem.includeTime) ? UIDatePickerModeDateAndTime : UIDatePickerModeDate;
            datePicker.minuteInterval = 10;
            datePicker.date = value;
            
            [UIView beginAnimations:nil context:NULL];
            datePicker.frame = CGRectMake(0, self.view.height - datePicker.height, datePicker.width, datePicker.height);
            table.frame = CGRectMake(0, 0, table.width, self.view.height - datePicker.height);
            [UIView commitAnimations];
            
            [table scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionBottom animated:YES];
            
            self.navigationItem.leftBarButtonItem = nil;
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"button.ok", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(dismissDatePicker)];
            
            self.formItemBeingEdited = formItem;

        } else {
            
            value = nil;
            if (datePicker.y < self.view.height) {
                [self dismissDatePicker];
            }
        }
        
    } else {
        
        if (datePicker.y < self.view.height) {
            [self dismissDatePicker];
        }
    }
    
    [listing setValue:value forKey:formItem.mapsTo];
    [table reloadData];
}

- (IBAction)postButtonPressed:(UIButton *)sender
{
    if (![[SharetribeAPIClient sharedClient] hasInternetConnectivity]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"alert.title.no_internet", @"") message:NSLocalizedString(@"alert.message.no_internet", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"button.ok", @"") otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    if (uploadTitleView == nil) {
        self.uploadTitleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 160, 40)];
        self.uploadProgressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 20)];
        uploadProgressLabel.font = [UIFont boldSystemFontOfSize:13];
        uploadProgressLabel.textColor = [UIColor whiteColor];
        uploadProgressLabel.shadowColor = [UIColor darkTextColor];
        uploadProgressLabel.shadowOffset = CGSizeMake(0, 1);
        uploadProgressLabel.backgroundColor = [UIColor clearColor];
        uploadProgressLabel.textAlignment = NSTextAlignmentCenter;
        self.uploadProgressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, 22, 160, 9)];
        [uploadTitleView addSubview:uploadProgressLabel];
        [uploadTitleView addSubview:uploadProgressView];
    }
    uploadProgressLabel.text = NSLocalizedString(@"composer.listing.posting", @"");
    uploadProgressView.progress = 0;
    self.navigationItem.titleView = uploadTitleView;
    
    if (convertingImage) {
        submissionWaitingForImage = YES;
        return;
    }
    
    listing.author = [User currentUser];
    listing.createdAt = [NSDate date];
    
    submitButton.enabled = NO;
    [submitButton setTitle:nil forState:UIControlStateNormal];
    [uploadSpinner startAnimating];
    
    [[SharetribeAPIClient sharedClient] postNewListing:listing];    
}

- (IBAction)cancelButtonPressed:(UIBarButtonItem *)sender
{
    if (listing.title != nil || listing.description != nil || listing.image != nil) {
        
        UIAlertView *alertViewForCanceling = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"button.cancel", @"") message:NSLocalizedString(@"alert.confirm_cancel_composing_listing", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"button.no", @"") otherButtonTitles:NSLocalizedString(@"button.yes", @""), nil];
        alertViewForCanceling.tag = kAlertViewTagForCanceling;
        [alertViewForCanceling show];
        
    } else {
        
        [self cancel];
    }
}

- (IBAction)mapPressed:(UIButton *)sender
{
    NSIndexPath *path = [table indexPathForRowAtPoint:[table convertPoint:CGPointZero fromView:sender]];    
    FormItem *formItem = [formItems objectAtIndex:path.row];
    CLLocation *location = [listing valueForKey:formItem.mapsTo];
    
    self.formItemBeingEdited = formItem;
    
    LocationPickerViewController *locationPicker = [[LocationPickerViewController alloc] init];
    locationPicker.delegate = self;
    locationPicker.coordinate = location.coordinate;
    [self.navigationController pushViewController:locationPicker animated:YES];
    preserveFormItemsOnNextAppearance = YES;
}

- (IBAction)datePickerValueChanged:(UIDatePicker *)picker
{
    [listing setValue:picker.date forKey:formItemBeingEdited.mapsTo];
    [formItemBeingEdited.alternatives replaceObjectAtIndex:0 withObject:picker.date];
    [table reloadData];
}

- (void)dismissDatePicker
{
    self.navigationItem.leftBarButtonItem = cancelButton;
    self.navigationItem.rightBarButtonItem = nil;
    
    [UIView beginAnimations:nil context:NULL];
    datePicker.frame = CGRectMake(0, self.view.height, datePicker.width, datePicker.height);
    table.frame = CGRectMake(0, 0, table.width, self.view.height);
    [UIView commitAnimations];
}

@end

@implementation CustomTextField

- (CGRect)textRectForBounds:(CGRect)bounds
{
    return CGRectInset(bounds, 8, 6);
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
    return CGRectInset(bounds, 8, 6);
}

@end
