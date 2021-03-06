#import "IOCMyRepositoriesController.h"
#import "RepositoryController.h"
#import "GHUser.h"
#import "GHRepository.h"
#import "GHRepositories.h"
#import "RepositoryCell.h"
#import "iOctocat.h"
#import "SVProgressHUD.h"
#import "IOCResourceStatusCell.h"
#import "IOCTableViewSectionHeader.h"


@interface IOCMyRepositoriesController ()
@property(nonatomic,strong)NSMutableArray *privateRepositories;
@property(nonatomic,strong)NSMutableArray *publicRepositories;
@property(nonatomic,strong)NSMutableArray *forkedRepositories;
@property(nonatomic,strong)GHUser *user;
@end


@implementation IOCMyRepositoriesController

- (id)initWithUser:(GHUser *)user {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		self.user = user;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.title = self.title ? self.title : @"Personal Repos";
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];
	if (self.user.repositories.isLoaded) {
		[self displayRepositories];
	} else {
		[self.user.repositories loadWithParams:nil success:^(GHResource *instance, id data) {
			[self displayRepositories];
		} failure:^(GHResource *instance, NSError *error) {
			[self.tableView reloadData];
		}];
	}
}

#pragma mark Helpers

- (BOOL)resourceHasData {
	return !self.user.repositories.isEmpty;
}

- (void)displayRepositories {
	NSComparisonResult (^compareRepositories)(GHRepository *, GHRepository *);
	compareRepositories = ^(GHRepository *repo1, GHRepository *repo2) {
		if (!repo1.pushedAtDate) return NSOrderedDescending;
		if (!repo2.pushedAtDate) return NSOrderedAscending;
		return (NSInteger)[repo2.pushedAtDate compare:repo1.pushedAtDate];
	};
	self.privateRepositories = [NSMutableArray array];
	self.publicRepositories = [NSMutableArray array];
	self.forkedRepositories = [NSMutableArray array];
	for (GHRepository *repo in self.user.repositories.items) {
		if (repo.isPrivate) {
			[self.privateRepositories addObject:repo];
		} else if (repo.isFork) {
			[self.forkedRepositories addObject:repo];
		} else {
			[self.publicRepositories addObject:repo];
		}
	}
	[self.privateRepositories sortUsingComparator:compareRepositories];
	[self.publicRepositories sortUsingComparator:compareRepositories];
	[self.forkedRepositories sortUsingComparator:compareRepositories];
	[self.tableView reloadData];
}

- (NSMutableArray *)repositoriesInSection:(NSInteger)section {
	if (section == 0) {
		return self.privateRepositories;
	} else if (section == 1) {
		return self.publicRepositories;
	} else {
		return self.forkedRepositories;
	}
}

#pragma mark Actions

- (IBAction)refresh:(id)sender {
	[SVProgressHUD showWithStatus:@"Reloading…"];
	[self.user.repositories loadWithParams:nil success:^(GHResource *instance, id data) {
		[SVProgressHUD dismiss];
		[self displayRepositories];
	} failure:^(GHResource *instance, NSError *error) {
		[SVProgressHUD showErrorWithStatus:@"Reloading failed"];
	}];
}

#pragma mark TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (self.resourceHasData) {
		return self.forkedRepositories.count > 0 ? 3 : 2;
	} else {
		return 1;
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (!self.resourceHasData) return 1;
	NSInteger count = [[self repositoriesInSection:section] count];
	return count == 0 ? 1 : count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return ([self tableView:tableView titleForHeaderInSection:section]) ? 24 : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    return (title == nil) ? nil : [IOCTableViewSectionHeader headerForTableView:tableView title:title];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (self.resourceHasData) {
		if (section == 0) {
			return @"Private";
		} else if (section == 1) {
			return @"Public";
		}  else if (section == 2) {
			return @"Forked";
		}
	}
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!self.resourceHasData) return [[IOCResourceStatusCell alloc] initWithResource:self.user.repositories name:@"repositories"];
	NSInteger section = indexPath.section;
	if (section == 0 && self.privateRepositories.count == 0) {
		return [[IOCResourceStatusCell alloc] initWithResource:self.user.repositories name:@"private repositories"];
	} else if (section == 1 && self.publicRepositories.count == 0) {
		return [[IOCResourceStatusCell alloc] initWithResource:self.user.repositories name:@"public repositories"];
	} else {
		RepositoryCell *cell = (RepositoryCell *)[tableView dequeueReusableCellWithIdentifier:kRepositoryCellIdentifier];
		if (cell == nil) cell = [RepositoryCell cell];
		NSArray *repos = [self repositoriesInSection:indexPath.section];
		cell.repository = repos[indexPath.row];
		[cell hideOwner];
		return cell;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *repos = [self repositoriesInSection:indexPath.section];
	if (repos.count == 0) return;
	GHRepository *repo = repos[indexPath.row];
	RepositoryController *repoController = [[RepositoryController alloc] initWithRepository:repo];
	[self.navigationController pushViewController:repoController animated:YES];
}

@end