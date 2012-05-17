/*
 * 02/05/2012
 *
 * JavaScriptTokenMaker.java - Parses a document into JavaScript tokens.
 * 
 * This library is distributed under a modified BSD license.  See the included
 * RSyntaxTextArea.License.txt file for details.
 */
package org.fife.ui.rsyntaxtextarea.modes;

import java.io.*;
import javax.swing.text.Segment;

import org.fife.ui.rsyntaxtextarea.*;


/**
 * Scanner for JavaScript files.  Its states could be simplified, but are
 * kept the way they are to keep a degree of similarity (i.e. copy/paste)
 * between it and HTML/JSP/PHPTokenMaker.  This should cause no difference in
 * performance.<p>
 *
 * This implementation was created using
 * <a href="http://www.jflex.de/">JFlex</a> 1.4.1; however, the generated file
 * was modified for performance.  Memory allocation needs to be almost
 * completely removed to be competitive with the handwritten lexers (subclasses
 * of <code>AbstractTokenMaker</code>, so this class has been modified so that
 * Strings are never allocated (via yytext()), and the scanner never has to
 * worry about refilling its buffer (needlessly copying chars around).
 * We can achieve this because RText always scans exactly 1 line of tokens at a
 * time, and hands the scanner this line as an array of characters (a Segment
 * really).  Since tokens contain pointers to char arrays instead of Strings
 * holding their contents, there is no need for allocating new memory for
 * Strings.<p>
 *
 * The actual algorithm generated for scanning has, of course, not been
 * modified.<p>
 *
 * If you wish to regenerate this file yourself, keep in mind the following:
 * <ul>
 *   <li>The generated JavaScriptTokenMaker.java</code> file will contain two
 *       definitions of both <code>zzRefill</code> and <code>yyreset</code>.
 *       You should hand-delete the second of each definition (the ones
 *       generated by the lexer), as these generated methods modify the input
 *       buffer, which we'll never have to do.</li>
 *   <li>You should also change the declaration/definition of zzBuffer to NOT
 *       be initialized.  This is a needless memory allocation for us since we
 *       will be pointing the array somewhere else anyway.</li>
 *   <li>You should NOT call <code>yylex()</code> on the generated scanner
 *       directly; rather, you should use <code>getTokenList</code> as you would
 *       with any other <code>TokenMaker</code> instance.</li>
 * </ul>
 *
 * @author Robert Futrell
 * @version 0.8
 *
 */
%%

%public
%class JavaScriptTokenMaker
%extends AbstractJFlexCTokenMaker
%unicode
%type org.fife.ui.rsyntaxtextarea.Token


%{

	/**
	 * Token type specifying we're in a JavaScript multiline comment.
	 */
	public static final int INTERNAL_IN_JS_MLC				= -8;

	/**
	 * Token type specifying we're in an invalid multi-line JS string.
	 */
	public static final int INTERNAL_IN_JS_STRING_INVALID	= -9;

	/**
	 * Token type specifying we're in a valid multi-line JS string.
	 */
	public static final int INTERNAL_IN_JS_STRING_VALID		= -10;

	/**
	 * Token type specifying we're in an invalid multi-line JS single-quoted string.
	 */
	public static final int INTERNAL_IN_JS_CHAR_INVALID	= -11;

	/**
	 * Token type specifying we're in a valid multi-line JS single-quoted string.
	 */
	public static final int INTERNAL_IN_JS_CHAR_VALID		= -12;

	/**
	 * When in the JS_STRING state, whether the current string is valid.
	 */
	private boolean validJSString;
	
	private static String jsVersion = "1.0";


	/**
	 * Constructor.  This must be here because JFlex does not generate a
	 * no-parameter constructor.
	 */
	public JavaScriptTokenMaker() {
		super();
	}
	
	/**
	* 
	* Set the supported JavaScript version because some keywords were introduced on or after this version
	*/
	public static void setJavaScriptVersion(String javaScriptVersion) {
		jsVersion = javaScriptVersion;
	}
	
	/*
	*
	* @return Supported JavaScript version
	*/
	public static String getJavaScriptVersion() {
		return jsVersion;
	}
	
	/**
	* @param JavaScript version required 
	* @return checks the JavaScript version is the same or greater than version required 
	*/
	private static boolean isJavaScriptCompatible(String version) {
		return jsVersion.compareTo(version) >= 0;
	}

	/**
	 * Adds the token specified to the current linked list of tokens as an
	 * "end token;" that is, at <code>zzMarkedPos</code>.
	 *
	 * @param tokenType The token's type.
	 */
	private void addEndToken(int tokenType) {
		addToken(zzMarkedPos,zzMarkedPos, tokenType);
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param tokenType The token's type.
	 * @see #addToken(int, int, int)
	 */
	private void addHyperlinkToken(int start, int end, int tokenType) {
		int so = start + offsetShift;
		addToken(zzBuffer, start,end, tokenType, so, true);
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param tokenType The token's type.
	 */
	private void addToken(int tokenType) {
		addToken(zzStartRead, zzMarkedPos-1, tokenType);
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param tokenType The token's type.
	 */
	private void addToken(int start, int end, int tokenType) {
		int so = start + offsetShift;
		addToken(zzBuffer, start,end, tokenType, so);
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param array The character array.
	 * @param start The starting offset in the array.
	 * @param end The ending offset in the array.
	 * @param tokenType The token's type.
	 * @param startOffset The offset in the document at which this token
	 *                    occurs.
	 */
	public void addToken(char[] array, int start, int end, int tokenType, int startOffset) {
		super.addToken(array, start,end, tokenType, startOffset);
		zzStartRead = zzMarkedPos;
	}


	/**
	 * {@inheritDoc}
	 */
	public String[] getLineCommentStartAndEnd() {
		return new String[] { "//", null };
	}


	/**
	 * Returns the first token in the linked list of tokens generated
	 * from <code>text</code>.  This method must be implemented by
	 * subclasses so they can correctly implement syntax highlighting.
	 *
	 * @param text The text from which to get tokens.
	 * @param initialTokenType The token type we should start with.
	 * @param startOffset The offset into the document at which
	 *        <code>text</code> starts.
	 * @return The first <code>Token</code> in a linked list representing
	 *         the syntax highlighted text.
	 */
	public Token getTokenList(Segment text, int initialTokenType, int startOffset) {

		resetTokenList();
		this.offsetShift = -text.offset + startOffset;

		// Start off in the proper state.
		int state = Token.NULL;
		switch (initialTokenType) {
			case INTERNAL_IN_JS_MLC:
				state = JS_MLC;
				start = text.offset;
				break;
			case INTERNAL_IN_JS_STRING_INVALID:
				state = JS_STRING;
				validJSString = false;
				start = text.offset;
				break;
			case INTERNAL_IN_JS_STRING_VALID:
				state = JS_STRING;
				validJSString = true;
				start = text.offset;
				break;
			case INTERNAL_IN_JS_CHAR_INVALID:
				state = JS_CHAR;
				validJSString = false;
				start = text.offset;
				break;
			case INTERNAL_IN_JS_CHAR_VALID:
				state = JS_CHAR;
				validJSString = true;
				start = text.offset;
				break;
			default:
				state = Token.NULL;
		}

		s = text;
		try {
			yyreset(zzReader);
			yybegin(state);
			return yylex();
		} catch (IOException ioe) {
			ioe.printStackTrace();
			return new DefaultToken();
		}

	}


	/**
	 * Refills the input buffer.
	 *
	 * @return      <code>true</code> if EOF was reached, otherwise
	 *              <code>false</code>.
	 */
	private boolean zzRefill() {
		return zzCurrentPos>=s.offset+s.count;
	}


	/**
	 * Resets the scanner to read from a new input stream.
	 * Does not close the old reader.
	 *
	 * All internal variables are reset, the old input stream 
	 * <b>cannot</b> be reused (internal buffer is discarded and lost).
	 * Lexical state is set to <tt>YY_INITIAL</tt>.
	 *
	 * @param reader   the new input stream 
	 */
	public final void yyreset(java.io.Reader reader) {
		// 's' has been updated.
		zzBuffer = s.array;
		/*
		 * We replaced the line below with the two below it because zzRefill
		 * no longer "refills" the buffer (since the way we do it, it's always
		 * "full" the first time through, since it points to the segment's
		 * array).  So, we assign zzEndRead here.
		 */
		//zzStartRead = zzEndRead = s.offset;
		zzStartRead = s.offset;
		zzEndRead = zzStartRead + s.count - 1;
		zzCurrentPos = zzMarkedPos = zzPushbackPos = s.offset;
		zzLexicalState = YYINITIAL;
		zzReader = reader;
		zzAtBOL  = true;
		zzAtEOF  = false;
	}


%}

Whitespace			= ([ \t\f]+)
LineTerminator			= ([\n])

Letter							= [A-Za-z]
NonzeroDigit						= [1-9]
Digit							= ("0"|{NonzeroDigit})
HexDigit							= ({Digit}|[A-Fa-f])
OctalDigit						= ([0-7])
EscapedSourceCharacter				= ("u"{HexDigit}{HexDigit}{HexDigit}{HexDigit})
NonSeparator						= ([^\t\f\r\n\ \(\)\{\}\[\]\;\,\.\=\>\<\!\~\?\:\+\-\*\/\&\|\^\%\"\']|"#"|"\\")
IdentifierStart					= ({Letter}|"_"|"$")
IdentifierPart						= ({IdentifierStart}|{Digit}|("\\"{EscapedSourceCharacter}))
JS_MLCBegin				= "/*"
JS_MLCEnd					= "*/"
JS_LineCommentBegin			= "//"
JS_IntegerHelper1			= (({NonzeroDigit}{Digit}*)|"0")
JS_IntegerHelper2			= ("0"(([xX]{HexDigit}+)|({OctalDigit}*)))
JS_IntegerLiteral			= ({JS_IntegerHelper1}[lL]?)
JS_HexLiteral				= ({JS_IntegerHelper2}[lL]?)
JS_FloatHelper1			= ([fFdD]?)
JS_FloatHelper2			= ([eE][+-]?{Digit}+{JS_FloatHelper1})
JS_FloatLiteral1			= ({Digit}+"."({JS_FloatHelper1}|{JS_FloatHelper2}|{Digit}+({JS_FloatHelper1}|{JS_FloatHelper2})))
JS_FloatLiteral2			= ("."{Digit}+({JS_FloatHelper1}|{JS_FloatHelper2}))
JS_FloatLiteral3			= ({Digit}+{JS_FloatHelper2})
JS_FloatLiteral			= ({JS_FloatLiteral1}|{JS_FloatLiteral2}|{JS_FloatLiteral3}|({Digit}+[fFdD]))
JS_ErrorNumberFormat		= (({JS_IntegerLiteral}|{JS_HexLiteral}|{JS_FloatLiteral}){NonSeparator}+)
JS_Separator				= ([\(\)\{\}\[\]\]])
JS_Separator2				= ([\;,.])
JS_NonAssignmentOperator		= ("+"|"-"|"<="|"^"|"++"|"<"|"*"|">="|"%"|"--"|">"|"/"|"!="|"?"|">>"|"!"|"&"|"=="|":"|">>"|"~"|"|"|"&&"|">>>")
JS_AssignmentOperator		= ("="|"-="|"*="|"/="|"|="|"&="|"^="|"+="|"%="|"<<="|">>="|">>>=")
JS_Operator				= ({JS_NonAssignmentOperator}|{JS_AssignmentOperator})
JS_Identifier				= ({IdentifierStart}{IdentifierPart}*)
JS_ErrorIdentifier			= ({NonSeparator}+)
JS_Regex					= ("/"([^\*\\/]|\\.)([^/\\]|\\.)*"/"[gim]*)

URLGenDelim				= ([:\/\?#\[\]@])
URLSubDelim				= ([\!\$&'\(\)\*\+,;=])
URLUnreserved			= ({Letter}|"_"|{Digit}|[\-\.\~])
URLCharacter			= ({URLGenDelim}|{URLSubDelim}|{URLUnreserved}|[%])
URLCharacters			= ({URLCharacter}*)
URLEndCharacter			= ([\/\$]|{Letter}|{Digit})
URL						= (((https?|f(tp|ile))"://"|"www.")({URLCharacters}{URLEndCharacter})?)


%state JS_STRING
%state JS_CHAR
%state JS_MLC
%state JS_EOL_COMMENT


%%

<YYINITIAL> {

	// ECMA 3+ keywords.
	"break" |
	"continue" |
	"delete" |
	"else" |
	"for" |
	"function" |
	"if" |
	"in" |
	"new" |
	"this" |
	"typeof" |
	"var" |
	"void" |
	"while" |
	"with"						{ addToken(Token.RESERVED_WORD); }
	"return"					{ addToken(Token.RESERVED_WORD_2); }
	
	//JavaScript 1.6
	"each" 						{if(isJavaScriptCompatible("1.6")){ addToken(Token.RESERVED_WORD);} else {addToken(Token.IDENTIFIER);} }
	//JavaScript 1.7
	"let" 						{if(isJavaScriptCompatible("1.7")){ addToken(Token.RESERVED_WORD);} else {addToken(Token.IDENTIFIER);} }
	
	// Reserved (but not yet used) ECMA keywords.
	"abstract"					{ addToken(Token.RESERVED_WORD); }
	"boolean"						{ addToken(Token.DATA_TYPE); }
	"byte"						{ addToken(Token.DATA_TYPE); }
	"case"						{ addToken(Token.RESERVED_WORD); }
	"catch"						{ addToken(Token.RESERVED_WORD); }
	"char"						{ addToken(Token.DATA_TYPE); }
	"class"						{ addToken(Token.RESERVED_WORD); }
	"const"						{ addToken(Token.RESERVED_WORD); }
	"debugger"					{ addToken(Token.RESERVED_WORD); }
	"default"						{ addToken(Token.RESERVED_WORD); }
	"do"							{ addToken(Token.RESERVED_WORD); }
	"double"						{ addToken(Token.DATA_TYPE); }
	"enum"						{ addToken(Token.RESERVED_WORD); }
	"export"						{ addToken(Token.RESERVED_WORD); }
	"extends"						{ addToken(Token.RESERVED_WORD); }
	"final"						{ addToken(Token.RESERVED_WORD); }
	"finally"						{ addToken(Token.RESERVED_WORD); }
	"float"						{ addToken(Token.DATA_TYPE); }
	"goto"						{ addToken(Token.RESERVED_WORD); }
	"implements"					{ addToken(Token.RESERVED_WORD); }
	"import"						{ addToken(Token.RESERVED_WORD); }
	"instanceof"					{ addToken(Token.RESERVED_WORD); }
	"int"						{ addToken(Token.DATA_TYPE); }
	"interface"					{ addToken(Token.RESERVED_WORD); }
	"long"						{ addToken(Token.DATA_TYPE); }
	"native"						{ addToken(Token.RESERVED_WORD); }
	"package"						{ addToken(Token.RESERVED_WORD); }
	"private"						{ addToken(Token.RESERVED_WORD); }
	"protected"					{ addToken(Token.RESERVED_WORD); }
	"public"						{ addToken(Token.RESERVED_WORD); }
	"short"						{ addToken(Token.DATA_TYPE); }
	"static"						{ addToken(Token.RESERVED_WORD); }
	"super"						{ addToken(Token.RESERVED_WORD); }
	"switch"						{ addToken(Token.RESERVED_WORD); }
	"synchronized"					{ addToken(Token.RESERVED_WORD); }
	"throw"						{ addToken(Token.RESERVED_WORD); }
	"throws"						{ addToken(Token.RESERVED_WORD); }
	"transient"					{ addToken(Token.RESERVED_WORD); }
	"try"						{ addToken(Token.RESERVED_WORD); }
	"volatile"					{ addToken(Token.RESERVED_WORD); }
	"null"						{ addToken(Token.RESERVED_WORD); }

	// Literals.
	"false" |
	"true"						{ addToken(Token.LITERAL_BOOLEAN); }
	"NaN"						{ addToken(Token.RESERVED_WORD); }
	"Infinity"					{ addToken(Token.RESERVED_WORD); }

	// Functions.
	"eval" |
	"parseInt" |
	"parseFloat" |
	"escape" |
	"unescape" |
	"isNaN" |
	"isFinite"						{ addToken(Token.FUNCTION); }

	{LineTerminator}				{ addNullToken(); return firstToken; }
	{JS_Identifier}					{ addToken(Token.IDENTIFIER); }
	{Whitespace}					{ addToken(Token.WHITESPACE); }

	/* String/Character literals. */
	[\']							{ start = zzMarkedPos-1; validJSString = true; yybegin(JS_CHAR); }
	[\"]							{ start = zzMarkedPos-1; validJSString = true; yybegin(JS_STRING); }

	/* Comment literals. */
	"/**/"						{ addToken(Token.COMMENT_MULTILINE); }
	{JS_MLCBegin}					{ start = zzMarkedPos-2; yybegin(JS_MLC); }
	{JS_LineCommentBegin}			{ start = zzMarkedPos-2; yybegin(JS_EOL_COMMENT); }

	/* Attempt to identify regular expressions (not foolproof) - do after comments! */
	{JS_Regex}						{
										boolean highlightedAsRegex = false;
										if (firstToken==null) {
											addToken(Token.REGEX);
											highlightedAsRegex = true;
										}
										else {
											// If this is *likely* to be a regex, based on
											// the previous token, highlight it as such.
											Token t = firstToken.getLastNonCommentNonWhitespaceToken();
											if (RSyntaxUtilities.regexCanFollowInJavaScript(t)) {
												addToken(Token.REGEX);
												highlightedAsRegex = true;
											}
										}
										// If it doesn't *appear* to be a regex, highlight it as
										// individual tokens.
										if (!highlightedAsRegex) {
											int temp = zzStartRead + 1;
											addToken(zzStartRead, zzStartRead, Token.OPERATOR);
											zzStartRead = zzCurrentPos = zzMarkedPos = temp;
										}
									}

	/* Separators. */
	{JS_Separator}					{ addToken(Token.SEPARATOR); }
	{JS_Separator2}				{ addToken(Token.IDENTIFIER); }

	/* Operators. */
	{JS_Operator}					{ addToken(Token.OPERATOR); }

	/* Numbers */
	{JS_IntegerLiteral}				{ addToken(Token.LITERAL_NUMBER_DECIMAL_INT); }
	{JS_HexLiteral}				{ addToken(Token.LITERAL_NUMBER_HEXADECIMAL); }
	{JS_FloatLiteral}				{ addToken(Token.LITERAL_NUMBER_FLOAT); }
	{JS_ErrorNumberFormat}			{ addToken(Token.ERROR_NUMBER_FORMAT); }

	{JS_ErrorIdentifier}			{ addToken(Token.ERROR_IDENTIFIER); }

	/* Ended with a line not in a string or comment. */
	<<EOF>>						{ addNullToken(); return firstToken; }

	/* Catch any other (unhandled) characters and flag them as bad. */
	.							{ addToken(Token.ERROR_IDENTIFIER); }

}

<JS_STRING> {
	[^\n\\\"]+				{}
	\n						{ addToken(start,zzStartRead-1, Token.ERROR_STRING_DOUBLE); addNullToken(); return firstToken; }
	\\x{HexDigit}{2}		{}
	\\x						{ /* Invalid latin-1 character \xXX */ validJSString = false; }
	\\u{HexDigit}{4}		{}
	\\u						{ /* Invalid Unicode character \\uXXXX */ validJSString = false; }
	\\.						{ /* Skip all escaped chars. */ }
	\\						{ /* Line ending in '\' => continue to next line. */
								if (validJSString) {
									addToken(start,zzStartRead, Token.LITERAL_STRING_DOUBLE_QUOTE);
									addEndToken(INTERNAL_IN_JS_STRING_VALID);
								}
								else {
									addToken(start,zzStartRead, Token.ERROR_STRING_DOUBLE);
									addEndToken(INTERNAL_IN_JS_STRING_INVALID);
								}
								return firstToken;
							}
	\"						{ int type = validJSString ? Token.LITERAL_STRING_DOUBLE_QUOTE : Token.ERROR_STRING_DOUBLE; addToken(start,zzStartRead, type); yybegin(YYINITIAL); }
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.ERROR_STRING_DOUBLE); addNullToken(); return firstToken; }
}

<JS_CHAR> {
	[^\n\\\']+				{}
	\n						{ addToken(start,zzStartRead-1, Token.ERROR_CHAR); addNullToken(); return firstToken; }
	\\x{HexDigit}{2}		{}
	\\x						{ /* Invalid latin-1 character \xXX */ validJSString = false; }
	\\u{HexDigit}{4}		{}
	\\u						{ /* Invalid Unicode character \\uXXXX */ validJSString = false; }
	\\.						{ /* Skip all escaped chars. */ }
	\\						{ /* Line ending in '\' => continue to next line. */
								if (validJSString) {
									addToken(start,zzStartRead, Token.LITERAL_CHAR);
									addEndToken(INTERNAL_IN_JS_CHAR_VALID);
								}
								else {
									addToken(start,zzStartRead, Token.ERROR_CHAR);
									addEndToken(INTERNAL_IN_JS_CHAR_INVALID);
								}
								return firstToken;
							}
	\'						{ int type = validJSString ? Token.LITERAL_CHAR : Token.ERROR_CHAR; addToken(start,zzStartRead, type); yybegin(YYINITIAL); }
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.ERROR_CHAR); addNullToken(); return firstToken; }
}

<JS_MLC> {
	// JavaScript MLC's.  This state is essentially Java's MLC state.
	[^hwf\n\*]+			{}
	{URL}					{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_EOL); addHyperlinkToken(temp,zzMarkedPos-1, Token.COMMENT_EOL); start = zzMarkedPos; }
	[hwf]					{}
	\n						{ addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); addEndToken(INTERNAL_IN_JS_MLC); return firstToken; }
	{JS_MLCEnd}				{ yybegin(YYINITIAL); addToken(start,zzStartRead+1, Token.COMMENT_MULTILINE); }
	\*						{}
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); addEndToken(INTERNAL_IN_JS_MLC); return firstToken; }
}

<JS_EOL_COMMENT> {
	[^hwf\n]+				{}
	{URL}					{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_EOL); addHyperlinkToken(temp,zzMarkedPos-1, Token.COMMENT_EOL); start = zzMarkedPos; }
	[hwf]					{}
	\n |
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.COMMENT_EOL); addNullToken(); return firstToken; }
}
