%option noyywrap noinput nounput never-interactive nodefault
%{
#include <stdio.h>

int line = 1;
int column = 1;

int token_count = 0;
int error_count = 0;

int block_comment_line;
int block_comment_column;

int string_line;
int string_column;

void advance_location(const char *text, int length)
{
    for (int i = 0; i < length; i++) {

        if (text[i] == '\r') {

            if (i + 1 < length && text[i + 1] == '\n') {
                i++;
            }

            line++;
            column = 1;
        }
        else if (text[i] == '\n') {
            line++;
            column = 1;
        }
        else {
            column++;
        }
    }
}

void emit_token(const char *token, const char *text, int length)
{
    printf("%d:%d  %s  %.*s\n", line, column, token, length, text);

    token_count++;

    advance_location(text, length);
}

void emit_error(int error_line, int error_column, const char *reason)
{
    fprintf(stderr, "%d:%d LEX_ERROR %s\n", error_line, error_column, reason);

    error_count++;
}
%}

DIGIT       [0-9]
HEXDIGIT    [0-9a-fA-F]
NUMCHAR     [a-zA-Z0-9_.]
NUMCAND     ({DIGIT}|[.]{DIGIT}){NUMCHAR}*

%x LINE_COMMENT
%x BLOCK_COMMENT
%x STRING

%%
"let"       { emit_token("KW_LET", yytext, yyleng); }
"int"       { emit_token("KW_INT", yytext, yyleng); }
"print"     { emit_token("KW_PRINT", yytext, yyleng); }
"if"        { emit_token("KW_IF", yytext, yyleng); }
"else"      { emit_token("KW_ELSE", yytext, yyleng); }
"for"       { emit_token("KW_FOR", yytext, yyleng); }
"while"     { emit_token("KW_WHILE", yytext, yyleng); }

"=="        { emit_token("EQ", yytext, yyleng); }
"!="        { emit_token("NE", yytext, yyleng); }
"<="        { emit_token("LE", yytext, yyleng); }
">="        { emit_token("GE", yytext, yyleng); }
"="         { emit_token("ASSIGN", yytext, yyleng); }
"<"         { emit_token("LT", yytext, yyleng); }
">"         { emit_token("GT", yytext, yyleng); }
"+"         { emit_token("PLUS", yytext, yyleng); }
"-"         { emit_token("MINUS", yytext, yyleng); }
"*"         { emit_token("STAR", yytext, yyleng); }

"//" { advance_location(yytext, yyleng);
    BEGIN(LINE_COMMENT); }
<LINE_COMMENT>\r\n { advance_location(yytext, yyleng);
    BEGIN(INITIAL); }
<LINE_COMMENT>\n { advance_location(yytext, yyleng);
    BEGIN(INITIAL); }
<LINE_COMMENT>\r { advance_location(yytext, yyleng); }
<LINE_COMMENT>[^\r\n]+ { advance_location(yytext, yyleng); }
<LINE_COMMENT><<EOF>> { return 0; }

"/*" {
    block_comment_line = line;
    block_comment_column = column;

    advance_location(yytext, yyleng);
    BEGIN(BLOCK_COMMENT);
}
<BLOCK_COMMENT>"*/" {
    advance_location(yytext, yyleng);
    BEGIN(INITIAL);
}
<BLOCK_COMMENT>\r\n { advance_location(yytext, yyleng); }
<BLOCK_COMMENT>\r { advance_location(yytext, yyleng); }
<BLOCK_COMMENT>\n { advance_location(yytext, yyleng); }
<BLOCK_COMMENT>[^*\r\n]+ { advance_location(yytext, yyleng); }
<BLOCK_COMMENT>"*" { advance_location(yytext, yyleng);}
<BLOCK_COMMENT><<EOF>> {
    emit_error(block_comment_line,
               block_comment_column,
               "unterminated block comment");

    return 0;
}

"/"         { emit_token("SLASH", yytext, yyleng); }
"%"         { emit_token("PERCENT", yytext, yyleng); }

";"         { emit_token("SEMICOLON", yytext, yyleng); }
"("         { emit_token("LPAREN", yytext, yyleng); }
")"         { emit_token("RPAREN", yytext, yyleng); }
"{"         { emit_token("LBRACE", yytext, yyleng); }
"}"         { emit_token("RBRACE", yytext, yyleng); }

0[xX]{HEXDIGIT}+ { emit_token("INT_LITERAL", yytext, yyleng); }

{DIGIT}+ { emit_token("INT_LITERAL", yytext, yyleng); }

\" {
    string_line = line;
    string_column = column;

    emit_token("STRING_BEGIN", yytext, yyleng);
    BEGIN(STRING);
}
<STRING>[^"\r\n]+ { emit_token("STRING_TEXT", yytext, yyleng); }
<STRING>\" {
    emit_token("STRING_END", yytext, yyleng);
    BEGIN(INITIAL);
}
<STRING>\r\n {
    emit_error(string_line, string_column, "unterminated string");
    advance_location(yytext, yyleng);
    BEGIN(INITIAL);
}
<STRING>\n {
    emit_error(string_line, string_column, "unterminated string");
    advance_location(yytext, yyleng);
    BEGIN(INITIAL);
}
<STRING>\r {
    emit_error(string_line, string_column, "unterminated string");
    advance_location(yytext, yyleng);
    BEGIN(INITIAL);
}
<STRING><<EOF>> {
    emit_error(string_line, string_column, "unterminated string");
    return 0;
}

{NUMCAND} { emit_error(line, column, "invalid integer spelling");
        advance_location(yytext, yyleng); }

[a-zA-Z_][a-zA-Z0-9_]* { emit_token("IDENTIFIER", yytext, yyleng); }

[ \t\r\n]+  { advance_location(yytext, yyleng); }

. { emit_error(line, column, "unexpected character");
    advance_location(yytext, yyleng);}

%%

int main(void)
{
    yylex();
    printf("SUMMARY N=%d E=%d\n", token_count, error_count);
    if (error_count == 0) {
        return 0;
    }
    else {
        return 1;
    }
}