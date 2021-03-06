
@import <Foundation/CPObject.j>

@import <Foundation/CPIndexSet.j>
@import <AppKit/CPTableColumn.j>
@import <AppKit/CPTableView.j>

tableTestDragType = @"CPTableViewTestDragType";
CPLogRegister(CPLogConsole);

@implementation AppController : CPObject
{
    CPTableView tableView;
    CPTableView tableView2;
    CPImage     iconImage;
    CPArray     dataSet1;
    CPArray     dataSet2;
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
    dataSet1 = [],
    dataSet2 = [];
    
    for(var i = 1; i < 100; i++)
    {
        dataSet1[i - 1] = [CPNumber numberWithInt:i];
        dataSet2[i - 1] = [CPNumber numberWithInt:i+10];
    }
    
    var window1 = [[CPWindow alloc] initWithContentRect:CGRectMake(50, 50, 500, 400) styleMask:CPTitledWindowMask | CPResizableWindowMask],
        view = [window1 contentView];
    
    [view setBackgroundColor:[CPColor whiteColor]];
    
    tableView = [[CPTableView alloc] initWithFrame:CGRectMake(0.0, 0.0, 500.0, 500.0)];

    [tableView setAllowsMultipleSelection:YES];
    [tableView setAllowsColumnSelection:YES];
    [tableView setUsesAlternatingRowBackgroundColors:YES];
    [tableView setAlternatingRowBackgroundColors:[[CPColor whiteColor], [CPColor colorWithHexString:@"e4e7ff"], [CPColor colorWithHexString:@"f4e7ff"]]];
    [tableView setGridStyleMask:CPTableViewSolidHorizontalGridLineMask | CPTableViewSolidVerticalGridLineMask];

    var iconView = [[CPImageView alloc] initWithFrame:CGRectMake(16,16,0,0)];

    [iconView setImageScaling:CPScaleNone];

    var iconColumn = [[CPTableColumn alloc] initWithIdentifier:"icons"];

    [iconColumn setWidth:32.0];
    [iconColumn setMinWidth:32.0];
    [iconColumn setDataView:iconView];

    [tableView addTableColumn:iconColumn];

    iconImage = [[CPImage alloc] initWithContentsOfFile:"http://cappuccino.org/images/favicon.png" size:CGSizeMake(16,16)];

    var desc = [CPSortDescriptor sortDescriptorWithKey:@"self" ascending:YES];
    for (var i = 1; i <= 2; i++)
    {
        var column = [[CPTableColumn alloc] initWithIdentifier:String(i)];
        [column setSortDescriptorPrototype:desc];
        [[column headerView] setStringValue:"Number "+i];

        [column setMinWidth:50.0];
        [column setMaxWidth:500.0];
        [column setWidth:200.0];
        
        [column setEditable:YES];
        [tableView addTableColumn:column];
    }

    [tableView setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];

    var scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth([view bounds]), CGRectGetHeight([view bounds]))];
    [tableView setRowHeight:22.0];
    [scrollView setDocumentView:tableView];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    
    [view addSubview:scrollView];

    [scrollView setAutohidesScrollers:YES];

    [tableView setDelegate:self];
    [tableView setDataSource:self];
    [tableView setVerticalMotionCanBeginDrag:NO];
    [tableView setDraggingDestinationFeedbackStyle:CPTableViewDropOn];
    [tableView registerForDraggedTypes:[CPArray arrayWithObject:tableTestDragType]];
    
    [window1 orderFront:self];
    [self newWindow];
}

- (void)newWindow
{

    var window2 = [[CPWindow alloc] initWithContentRect:CGRectMake(450, 50, 500, 400) styleMask:CPTitledWindowMask | CPResizableWindowMask];
    
    tableView2 = [[CPTableView alloc] initWithFrame:CGRectMake(0.0, 0.0, 500.0, 500.0)];

    [tableView2 setAllowsMultipleSelection:YES];
    [tableView2 setUsesAlternatingRowBackgroundColors:YES];
    [tableView2 setGridStyleMask:CPTableViewSolidHorizontalGridLineMask | CPTableViewSolidVerticalGridLineMask];


    var iconView = [[CPImageView alloc] initWithFrame:CGRectMake(16,16,0,0)];

    [iconView setImageScaling:CPScaleNone];

    var iconColumn = [[CPTableColumn alloc] initWithIdentifier:"icons"];

    [iconColumn setWidth:32.0];
    [iconColumn setMinWidth:32.0];
    [iconColumn setDataView:iconView];
    [iconColumn setResizingMask:CPTableColumnNoResizing];

    [tableView2 addTableColumn:iconColumn];

    iconImage = [[CPImage alloc] initWithContentsOfFile:"http://cappuccino.org/images/favicon.png" size:CGSizeMake(16,16)];

    var textDataView = [CPTextField new];
    
    [textDataView setValue:[CPColor whiteColor] forThemeAttribute:@"text-color" inState:CPThemeStateHighlighted];
    [textDataView setValue:[CPFont systemFontOfSize:12] forThemeAttribute:@"font" inState:CPThemeStateHighlighted];

    var desc = [CPSortDescriptor sortDescriptorWithKey:@"self" ascending:YES];

    for (var i = 1; i <= 3; i++)
    {
        var column = [[CPTableColumn alloc] initWithIdentifier:String(i)];
        [[column headerView] setStringValue:"Number "+i];

        [column setWidth:200.0];
        [column setMinWidth:50.0];

        [column setDataView:textDataView];
        [column setEditable:YES];
        
        [tableView2 addTableColumn:column];
    }

    [tableView2 setColumnAutoresizingStyle:CPTableViewUniformColumnAutoresizingStyle];

    var scrollView = [[CPScrollView alloc] initWithFrame:[[window2 contentView] bounds]];
    [tableView2 setRowHeight:32.0];
    [scrollView setDocumentView:tableView2];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    
    [[window2 contentView] addSubview:scrollView];

    [scrollView setAutohidesScrollers:YES];

    [tableView2 setDelegate:self];
    [tableView2 setDataSource:self];
    
    [tableView2 setVerticalMotionCanBeginDrag:NO];
    [tableView2 registerForDraggedTypes:[CPArray arrayWithObject:tableTestDragType]];
    [tableView2 setDraggingDestinationFeedbackStyle:CPTableViewDropAbove];
    
    [window2 orderFront:self];
}

- (int)numberOfRowsInTableView:(CPTableView)atableView
{
    if(atableView === tableView)
        return dataSet1.length;
    else if(atableView === tableView2)
        return dataSet2.length;
}

- (id)tableView:(CPTableView)atableView objectValueForTableColumn:(CPTableColumn)tableColumn row:(int)row
{

    if(atableView === tableView)
    {
         if ([tableColumn identifier] === "icons")
             return iconImage;
         else
             return String(dataSet1[row]);
    }
    else if(atableView === tableView2)
    {
        if ([tableColumn identifier] === "icons")
             return iconImage;
         else
             return String(dataSet2[row]);
    }
}

- (id)tableView:(CPTableView)tableView heightOfRow:(int)row
{
    return 50;
}

- (void)tableViewSelectionIsChanging:(CPNotification)aNotification
{
	CPLog.debug(@"changing! %@", [aNotification description]);
}

- (void)tableViewSelectionDidChange:(CPNotification)aNotification
{
	CPLog.debug(@"did change! %@", [aNotification description]);
}

- (BOOL)tableView:(CPTableView)aTableView shouldSelectRow:(int)rowIndex
{
    //CPLog.debug(@"tableView:shouldSelectRow");
    return true;
}

- (BOOL)selectionShouldChangeInTableView:(CPTableView)aTableView
{
	//CPLog.debug(@"selectionShouldChangeInTableView");
	return YES;
}

- (void)tableViewSelectionDidChange:(id)notification
{
    CPLogConsole(_cmd + [notification description]);
}

- (void)tableViewSelectionIsChanging:(id)notification
{
    CPLogConsole(_cmd + [notification description]);
}

- (void)_tableViewColumnDidResize:(id)notification
{
    CPLogConsole(_cmd + [notification description]);
}

//- (CPIndexSet)tableView:(CPTableView)tableView selectionIndexesForProposedSelection:(CPIndexSet)proposedSelectionIndexes
//{
//	CPLog.debug(@"selectionIndexesForProposedSelection %@", [proposedSelectionIndexes description]);
//	return proposedSelectionIndexes;
//}


- (BOOL)tableView:(CPTableView)aTableView shouldEditTableColumn:(CPTableColumn)tableColumn row:(int)row
{
    return NO;
}

- (void)tableView:(CPTableView)aTableView willDisplayView:(CPView)aView forTableColumn:(CPTableColumn)tableColumn row:(int)row
{
    CPLogConsole(_cmd + " column: " + [tableColumn identifier] + " row:" + row)    
}

- (void)tableView:(CPTableView)aTableView setObjectValue:(id)aValue forTableColumn:(CPTableColumn)tableColumn row:(int)row
{
    
}

- (void)tableView:(CPTableView)aTableView sortDescriptorsDidChange:(CPArray)oldDescriptors
{
    CPLogConsole(_cmd + [oldDescriptors description]);
    
    var newDescriptors = [aTableView sortDescriptors];
    
    [(aTableView === tableView) ? dataSet1:dataSet2 sortUsingDescriptors:newDescriptors];
	[aTableView reloadData];
}

- (BOOL)tableView:(CPTableView)aTableView writeRowsWithIndexes:(CPIndexSet)rowIndexes toPasteboard:(CPPasteboard)pboard
{
    var data = [rowIndexes, [aTableView UID]];
    
    var encodedData = [CPKeyedArchiver archivedDataWithRootObject:data];
    [pboard declareTypes:[CPArray arrayWithObject:tableTestDragType] owner:self];
    [pboard setData:encodedData forType:tableTestDragType];
    
    return YES;
}

- (CPDragOperation)tableView:(CPTableView)aTableView 
                   validateDrop:(id)info 
                   proposedRow:(CPInteger)row 
                   proposedDropOperation:(CPTableViewDropOperation)operation
{
    [[aTableView window] orderFront:nil];

    if(aTableView === tableView)
        [aTableView setDropRow:row dropOperation:CPTableViewDropOn];
    else 
        [aTableView setDropRow:row dropOperation:CPTableViewDropAbove];
        
    return CPDragOperationMove;
}

- (BOOL)tableView:(CPTableView)aTableView acceptDrop:(id)info row:(int)row dropOperation:(CPTableViewDropOperation)operation
{    
    var pboard = [info draggingPasteboard],
        rowData = [pboard dataForType:tableTestDragType],
        tables = [tableView, tableView2],
        dataSets = [dataSet1, dataSet2];   
    
    rowData = [CPKeyedUnarchiver unarchiveObjectWithData:rowData];
    
    var sourceIndexes = rowData[0],
        sourceTableUID = rowData[1];
     
    var index = (aTableView == tableView) ? 1 : 0;
        
    var destinationTable = tables[1 - index],
        sourceTable = tables[index],
        destinationDataSet = dataSets[1 - index],
        sourceDataSet = dataSets[index];

    if(operation | CPDragOperationMove)
    {
        if (sourceTableUID == [aTableView UID])
        {
            [destinationDataSet moveIndexes:sourceIndexes toIndex:row];
            [destinationTable reloadData];
            var destIndexes = [CPIndexSet indexSetWithIndexesInRange:CPMakeRange(row, [sourceIndexes count])];
            [destinationTable selectRowIndexes:destIndexes byExtendingSelection:NO];            
        }
        else
        {
            var destIndexes = [CPIndexSet indexSetWithIndexesInRange:CPMakeRange(row, [sourceIndexes count])];
            var sourceObjects = [sourceDataSet objectsAtIndexes:sourceIndexes];

            [destinationDataSet insertObjects:sourceObjects atIndexes:destIndexes];
            [destinationTable reloadData];
            [destinationTable selectRowIndexes:destIndexes byExtendingSelection:NO];
            
            [sourceDataSet removeObjectsAtIndexes:sourceIndexes];
            [sourceTable reloadData];
            [sourceTable selectRowIndexes:[CPIndexSet indexSet] byExtendingSelection:NO];                
        }
    }
        
    return YES;
}

- (void)tableView:(CPTableView)aTableView didEndDraggedImage:(CPImage)anImage atPosition:(CGPoint)aPoint operation:(CPDragOperation)anOperation
{
    //for convenience     
}

- (void)tableView:(CPTableView)aTableView didClickTableColumn:(CPTableColumn)aColumn
{
    console.log("table: "+aTableView+" clicked column: "+aColumn);
}

@end

@implementation CPArray (MoveIndexes)

- (void)moveIndexes:(CPIndexSet)indexes toIndex:(int)insertIndex
{
    var aboveCount = 0,
        object,
        removeIndex;
	
	var index = [indexes lastIndex];
	
    while (index != CPNotFound)
	{
		if (index >= insertIndex)
		{
			removeIndex = index + aboveCount;
			aboveCount ++;
		}
		else
		{
			removeIndex = index;
			insertIndex --;
		}
		
		object = [self objectAtIndex:removeIndex];
		[self removeObjectAtIndex:removeIndex];
		[self insertObject:object atIndex:insertIndex];
		
		index = [indexes indexLessThanIndex:index];
	}
}

@end
