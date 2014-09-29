//
//  main.c
//  regex
//
//  Created by nosources on 14-9-29.
//  Copyright (c) 2014年 nosources. All rights reserved.
//

#include <stdio.h>
#include <regex.h>
#include <string.h>
int main(int argc, const char * argv[])
{
    
    regex_t exp;
    char *pattrn = "GET /([a-zA-Z0-9_.-]*) HTTP";
    char *p = "GET /23---3--.html HTTP";
    if (0 != regcomp(&exp, pattrn, REG_EXTENDED)) {
        printf("regcomp call error.\n");
        return -1;
    }
    int matchLen = 2;
    regmatch_t match[matchLen];
    int exec_result = regexec(&exp, p, matchLen, match, 0);
    if (exec_result == 0) {
        char temp[50] = {0};
        strncpy(temp, p + match[1].rm_so, match[1].rm_eo - match[1].rm_so);
        printf("match is: \"%s\".\n", temp);
    }else if(exec_result == REG_NOMATCH){
        printf("no match.\n");
    }else{
        char error_msg[100] = {0};
        regerror(exec_result, &exp, error_msg, sizeof(error_msg));
        return -1;
    }
    regfree(&exp);
    
    
    return 0;
}

