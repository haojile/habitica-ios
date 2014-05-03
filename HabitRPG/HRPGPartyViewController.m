//
//  HRPGTableViewController.m
//  HabitRPG
//
//  Created by Phillip Thelen on 08/03/14.
//  Copyright (c) 2014 Phillip Thelen. All rights reserved.
//

#import "HRPGPartyViewController.h"
#import "HRPGAppDelegate.h"
#import "HRPGQuestInvitationViewController.h"
#import "HRPGQuestParticipantsViewController.h"
#import "Task.h"
#import "Group.h"
#import "Quest.h"
#import "User.h"
#import "QuestCollect.h"
#import "ChatMessage.h"
#import <NSDate+TimeAgo.h>
#import "NSString+Emoji.h"

@interface HRPGPartyViewController ()
@property HRPGManager *sharedManager;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation HRPGPartyViewController
@synthesize managedObjectContext;
@dynamic sharedManager;
Group *party;
Quest *quest;
User *user;
NSUserDefaults *defaults;
NSString *partyID;

- (void)viewDidLoad
{
    [super viewDidLoad];
    user = [self.sharedManager getUser];
    
    defaults = [NSUserDefaults standardUserDefaults];
    partyID = [defaults objectForKey:@"partyID"];
    if (!partyID || [partyID isEqualToString:@""]) {
        [self.sharedManager fetchGroups:@"party" onSuccess:^(){
            partyID = [defaults objectForKey:@"partyID"];
            party = [self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
            [self refresh];
        }onError:^() {
            
        }];
    } else {
        if ([[self.fetchedResultsController sections] count] > 0 && [[[self.fetchedResultsController sections] objectAtIndex:0] numberOfObjects] > 0) {
            party = [self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
            [self fetchQuest];
        } else {
            [self refresh];
        }

    }

    
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresh;
    
    
}

- (void) refresh {
    [self.sharedManager fetchGroup:@"party" onSuccess:^ () {
        [self.refreshControl endRefreshing];
        party = [self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        if (party.questKey != nil) {
            [self fetchQuest];
        }
        if (party.questKey != nil && !party.questActive && user.participateInQuest == nil) {
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
            UINavigationController *navigationController = (UINavigationController *)[storyboard instantiateViewControllerWithIdentifier:@"questInvitationNavigationController"];
            HRPGQuestInvitationViewController *questInvitationController = (HRPGQuestInvitationViewController*)navigationController.topViewController;
            questInvitationController.quest = quest;
            questInvitationController.party = party;
            questInvitationController.sourceViewcontroller = self;
            [self presentViewController:navigationController animated:YES completion: nil];
        }
    } onError:^ () {
        [self.refreshControl endRefreshing];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (party) {
        return 3;
    } else {
        return 1;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            if (party) {
                return 2;
            } else {
                return 1;
            }
        case 1:
            if (party.questKey && [quest.bossHp integerValue] == 0) {
                return [quest.collect count] + 2;
            } else if (party.questKey) {
                return 2;
            } else {
                return 1;
            }
        case 2: {
            if (party != nil && [party.chatmessages count] > 0) {
                return [party.chatmessages count];
            }
        }
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            if (party) {
                return party.name;
            } else {
                return NSLocalizedString(@"Party", nil);
            }
        case 1:
            return NSLocalizedString(@"Quest", nil);
        case 2:
            return NSLocalizedString(@"Chat", nil);
        default:
            return @"";
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && indexPath.item == 0) {
        if (![party.questActive boolValue] || ([quest.bossHp integerValue] == 0)) {
            NSInteger height = [quest.text boundingRectWithSize:CGSizeMake(280.0f, MAXFLOAT)
                                                          options:NSStringDrawingUsesLineFragmentOrigin
                                                       attributes:@{
                                                                    NSFontAttributeName : [UIFont systemFontOfSize:18.0f]
                                                                    }
                                                          context:nil].size.height+22;
            return height;
        } else {
            return 100;
        }
    } else if (indexPath.section == 0 && indexPath.item == 0) {
        if (!party) {
            return 60;
        }
        return [party.hdescription boundingRectWithSize:CGSizeMake(290.0f, MAXFLOAT)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{
                                                   NSFontAttributeName : [UIFont systemFontOfSize:15.0f]
                                                   }
                                         context:nil].size.height + 20;
    } else if (indexPath.section == 0) {
        return 44;
    } else if (indexPath.section == 1) {
        if ([party.questActive boolValue]) {
            return 44;
        } else {
            return 50;
        }
    } else {
        ChatMessage *message = party.chatmessages[indexPath.item];
        float width;
        if (message.user == nil) {
            width = 280.0f;
        } else {
            width = 230.0f;
        }
        NSInteger height = [message.text boundingRectWithSize:CGSizeMake(width, MAXFLOAT)
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:@{
                                                               NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody]
                                                               }
                                                     context:nil].size.height + 40;
        if (height < 70 && message.user != nil) {
            height = 70;
        }
        return height;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && indexPath.item == 1) {
        [self performSegueWithIdentifier: @"MembersSegue" sender: self];
    } else if (indexPath.section == 1 && indexPath.item == 1) {
        [self performSegueWithIdentifier: @"ParticipantsSegue" sender: self];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellname;
    if (indexPath.section == 0 && indexPath.item == 0) {
        if (party) {
            cellname = @"SmallTextCell";
        } else {
            cellname = @"NoPartyDataCell";
        }
    } else if (indexPath.section == 0 && indexPath.item == 1) {
        cellname = @"BaseCell";
    } else if (indexPath.section == 1 && indexPath.item == 0) {
        if (party.questKey == nil) {
            cellname = @"NoQuestCell";
        } else if (![party.questActive boolValue]) {
            cellname = @"BaseCell";
        } else {
            if ([quest.bossHp integerValue] > 0) {
                cellname = @"BossQuestCell";
            } else {
                cellname = @"CollectQuestCell";
            }
        }
    } else if (indexPath.section == 1 && indexPath.item == 1) {
        if ([party.questActive boolValue]) {
            cellname = @"BaseCell";
        } else {
            cellname = @"SubtitleCell";
        }
    } else if (indexPath.section == 1) {
        cellname = @"CollectItemQuestCell";
    } else {
        ChatMessage *message = (ChatMessage*)party.chatmessages[indexPath.item];
        if (message.user != nil) {
            cellname = @"ImageChatCell";
        } else {
            cellname = @"ChatCell";
        }
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellname forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}



- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Group" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"id == %@", partyID]];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"id" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"party"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    switch(type) {
        case NSFetchedResultsChangeUpdate:
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView reloadData];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    if (party != nil) {
        if (indexPath.section == 0 && indexPath.item == 0) {
            cell.textLabel.text = party.hdescription;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.section == 0 && indexPath.item == 1) {
            if ([party.member count] == 1) {
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.textLabel.text = NSLocalizedString(@"1 Member", nil);
            } else {
                cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%lu Members", nil), (unsigned long)[party.member count]];
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (indexPath.section == 1 && indexPath.item == 0) {
            if (party.questKey != nil) {
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                UILabel *titleLabel = (UILabel*)[cell viewWithTag:1];
                titleLabel.text = quest.text;
                if ([party.questHP integerValue] > 0) {
                    
                    UILabel *lifeLabel = (UILabel*)[cell viewWithTag:2];
                    lifeLabel.text = [NSString stringWithFormat:@"%@ / %@", party.questHP, quest.bossHp];
                    UIProgressView *lifeBar = (UIProgressView*)[cell viewWithTag:3];
                    lifeBar.progress = ([party.questHP floatValue] / [quest.bossHp floatValue]);
                } else {
                }
            }
        } else if (indexPath.section == 1 && indexPath.item == 1) {
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            int acceptedCount = 0;
            
            if ([party.questActive boolValue]) {
                for (User *participant in party.member) {
                    if ([participant.participateInQuest boolValue]) {
                        acceptedCount++;
                    }
                }
                if (acceptedCount == 1) {
                    cell.textLabel.text = NSLocalizedString(@"1 Participant", nil);
                } else {
                    cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%d Participants", nil), acceptedCount];
                }
            } else {
                cell.textLabel.text = NSLocalizedString(@"Participants", nil);
                for (User *participant in party.member) {
                    if (participant.participateInQuest != nil) {
                        acceptedCount++;
                    }
                }
                cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%d out of %d responded", nil), acceptedCount, [party.member count]];
                
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
        } else if (indexPath.section == 1) {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            QuestCollect *collect = quest.collect[indexPath.item-2];
            UILabel *authorLabel = (UILabel*)[cell viewWithTag:1];
            authorLabel.text = collect.text;
            if ([collect.count integerValue] == [collect.collectCount integerValue]) {
                authorLabel.textColor = [UIColor grayColor];
            } else {
                authorLabel.textColor = [UIColor blackColor];
            }
            
            UILabel *textLabel = (UILabel*)[cell viewWithTag:2];
            textLabel.text = [NSString stringWithFormat:@"%@/%@", collect.collectCount, collect.count];
        } else if (indexPath.section == 2) {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            ChatMessage *message = (ChatMessage*)party.chatmessages[indexPath.item];
            UILabel *authorLabel = (UILabel*)[cell viewWithTag:1];
            authorLabel.text = message.user;
            UILabel *textLabel = (UILabel*)[cell viewWithTag:2];
            if (message.user != nil) {
                UIImageView *imageView = (UIImageView*)[cell viewWithTag:5];
                [message.userObject setAvatarOnImageView:imageView withPetMount:NO onlyHead:YES];
            }
            textLabel.text = [message.text stringByReplacingEmojiCheatCodesWithUnicode];
            UILabel *dateLabel = (UILabel*)[cell viewWithTag:3];
            dateLabel.text = [message.timestamp timeAgo];
            //[dateLabel sizeToFit];
        }
    }
}

-(void) fetchQuest {
    if (party.questKey) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        // Edit the entity name as appropriate.
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Quest" inManagedObjectContext:self.managedObjectContext];
        [fetchRequest setEntity:entity];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"key == %@", party.questKey]];
        NSError *error;
        quest = [managedObjectContext executeFetchRequest:fetchRequest error:&error][0];
        [self.tableView reloadData];

    }
}

#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"ParticipantsSegue"]) {
        HRPGQuestParticipantsViewController *qpViewcontroller = segue.destinationViewController;
        qpViewcontroller.party = party;
        qpViewcontroller.quest = quest;
    }
}

@end
