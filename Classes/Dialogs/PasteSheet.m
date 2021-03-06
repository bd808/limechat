// LimeChat is copyrighted free software by Satoshi Nakagawa <psychs AT limechat DOT net>.
// You can redistribute it and/or modify it under the terms of the GPL version 2 (see the file GPL.txt).

#import "PasteSheet.h"
#import "NSStringHelper.h"


static NSArray* SYNTAXES;
static NSDictionary* SYNTAX_EXT_MAP;


@implementation PasteSheet
{
    GistClient* _gist;
}

- (id)init
{
    self = [super init];
    if (self) {
        [NSBundle loadNibNamed:@"PasteSheet" owner:self];

        if (!SYNTAXES) {
            SYNTAXES = [NSArray arrayWithObjects:
                         @"privmsg", @"notice", @"c", @"css", @"diff", @"html",
                         @"java", @"javascript", @"php", @"plain text", @"python",
                         @"ruby", @"sql", @"shell script", @"perl", @"haskell",
                         @"scheme", @"objective-c",
                         nil];
        }

        if (!SYNTAX_EXT_MAP) {
            SYNTAX_EXT_MAP = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"C", @"c",
                               @"CSS", @"css",
                               @"Diff", @"diff",
                               @"Haskell", @"haskell",
                               @"HTML", @"html",
                               @"Java", @"java",
                               @"JavaScript", @"javascript",
                               @"Objective-C", @"objective-c",
                               @"Perl", @"perl",
                               @"PHP", @"php",
                               @"Text", @"plain_text",
                               @"Python", @"python",
                               @"Ruby", @"ruby",
                               @"Scheme", @"scheme",
                               @"Shell", @"shell script",
                               @"SQL", @"sql",
                               nil, nil];
        }
    }
    return self;
}

- (void)dealloc
{
    [_gist cancel];
}

- (void)start
{
    if (_editMode) {
        NSArray* lines = [_originalText splitIntoLines];
        _isShortText = lines.count <= 3;
        if (_isShortText) {
            self.syntax = @"privmsg";
        }
        [sheet makeFirstResponder:bodyText];
    }

    [syntaxPopup selectItemWithTag:[self tagFromSyntax:_syntax]];
    [commandPopup selectItemWithTag:[self tagFromSyntax:_command]];
    [bodyText setString:_originalText];

    if (!NSEqualSizes(_size, NSZeroSize)) {
        [sheet setContentSize:_size];
    }

    [self startSheet];
}

- (void)pasteOnline:(id)sender
{
    [self setRequesting:YES];

    if (_gist) {
        [_gist cancel];
    }

    NSString* s = bodyText.string;
    NSString* fileType = [SYNTAX_EXT_MAP objectForKey:[self syntaxFromTag:syntaxPopup.selectedTag]];
    if (!fileType) {
        fileType = @"Text";
    }

    _gist = [GistClient new];
    _gist.delegate = self;
    [_gist send:s fileType:fileType private:YES];
}

- (void)sendInChannel:(id)sender
{
    _command = [self syntaxFromTag:commandPopup.selectedTag];

    NSString* s = bodyText.string;

    if ([self.delegate respondsToSelector:@selector(pasteSheet:onPasteText:)]) {
        [self.delegate pasteSheet:self onPasteText:s];
    }

    [self endSheet];
}

- (void)cancel:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(pasteSheetOnCancel:)]) {
        [self.delegate pasteSheetOnCancel:self];
    }

    [super cancel:nil];
}

- (void)setRequesting:(BOOL)value
{
    errorLabel.stringValue = value ? @"Sending…" : @"";
    if (value) {
        [uploadIndicator startAnimation:nil];
    }
    else {
        [uploadIndicator stopAnimation:nil];
    }

    [pasteOnlineButton setEnabled:!value];
    [sendInChannelButton setEnabled:!value];
    [syntaxPopup setEnabled:!value];
    [commandPopup setEnabled:!value];

    if (value) {
        [bodyText setEditable:NO];
        [bodyText setTextColor:[NSColor disabledControlTextColor]];
        [bodyText setBackgroundColor:[NSColor windowBackgroundColor]];
    }
    else {
        [bodyText setTextColor:[NSColor textColor]];
        [bodyText setBackgroundColor:[NSColor textBackgroundColor]];
        [bodyText setEditable:YES];
    }
}

- (int)tagFromSyntax:(NSString*)s
{
    NSUInteger n = [SYNTAXES indexOfObject:s];
    if (n != NSNotFound) {
        return n;
    }
    return -1;
}

- (NSString*)syntaxFromTag:(int)tag
{
    if (0 <= tag && tag < SYNTAXES.count) {
        return [SYNTAXES objectAtIndex:tag];
    }
    return nil;
}

#pragma mark -
#pragma mark GistClient Delegate

- (void)gistClient:(GistClient*)sender didReceiveResponse:(NSString*)url
{
    _gist = nil;

    [self setRequesting:NO];

    if (url.length) {
        [errorLabel setStringValue:@""];

        if ([self.delegate respondsToSelector:@selector(pasteSheet:onPasteURL:)]) {
            [self.delegate pasteSheet:self onPasteURL:url];
        }

        [self endSheet];
    }
    else {
        [errorLabel setStringValue:@"Could not get an URL from Gist"];
    }
}

- (void)gistClient:(GistClient*)sender didFailWithError:(NSString*)error statusCode:(int)statusCode
{
    _gist = nil;

    [self setRequesting:NO];
    [errorLabel setStringValue:[NSString stringWithFormat:@"Gist error: %@", error]];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification*)note
{
    _syntax = [self syntaxFromTag:syntaxPopup.selectedTag];
    _command = [self syntaxFromTag:commandPopup.selectedTag];

    NSView* contentView = [sheet contentView];
    _size = contentView.frame.size;

    if ([self.delegate respondsToSelector:@selector(pasteSheetWillClose:)]) {
        [self.delegate pasteSheetWillClose:self];
    }
}

@end
