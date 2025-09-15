/*****************************************************************************

Copyright (c) 1997, 2009, Innobase Oy. All Rights Reserved.
Copyright (c) 2024, Sunny Bains. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; version 2 of the License.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place, Suite 330, Boston, MA 02111-1307 USA

*****************************************************************************/

/******************************************************
SQL parser: input file for the GNU Bison parser generator

Look from pars0lex.l for instructions how to generate the C files for
the InnoDB parser.

Created 12/14/1997 Heikki Tuuri
Updated 8/13/2025  Fabio N. Filasieno: made the parser reentrant; remove make_* shell scripts to generate the parser
*******************************************************/

%{

#include "pars0pars.h"
#include "mem0mem.h"
#include "que0types.h"
#include "que0que.h"
#include "row0sel.h"

// The value of the semantic attribute is a pointer to a query tree node que_node_t
#define YYSTYPE que_node_t*

%}

%define api.pure full

%define api.value.type { que_node_t* }

%parse-param { Parser_context* ctx }
%parse-param { yyscan_t scanner    }
%lex-param   { yyscan_t scanner    }

%code requires {
  #include "pars0pars.h"
  #include "que0types.h"
  int yylex(que_node_t** yylval_param, yyscan_t scanner);
  void yyerror(Parser_context* ctx, yyscan_t scanner, const char* s);
}

%token PARS_INT_LIT
%token PARS_FLOAT_LIT
%token PARS_STR_LIT
%token PARS_FIXBINARY_LIT
%token PARS_BLOB_LIT
%token PARS_NULL_LIT
%token PARS_ID_TOKEN
%token PARS_AND_TOKEN
%token PARS_OR_TOKEN
%token PARS_NOT_TOKEN
%token PARS_GE_TOKEN
%token PARS_LE_TOKEN
%token PARS_NE_TOKEN
%token PARS_PROCEDURE_TOKEN
%token PARS_IN_TOKEN
%token PARS_OUT_TOKEN
%token PARS_BINARY_TOKEN
%token PARS_BLOB_TOKEN
%token PARS_INT_TOKEN
%token PARS_INTEGER_TOKEN
%token PARS_FLOAT_TOKEN
%token PARS_CHAR_TOKEN
%token PARS_IS_TOKEN
%token PARS_BEGIN_TOKEN
%token PARS_END_TOKEN
%token PARS_IF_TOKEN
%token PARS_THEN_TOKEN
%token PARS_ELSE_TOKEN
%token PARS_ELSIF_TOKEN
%token PARS_LOOP_TOKEN
%token PARS_WHILE_TOKEN
%token PARS_RETURN_TOKEN
%token PARS_SELECT_TOKEN
%token PARS_SUM_TOKEN
%token PARS_COUNT_TOKEN
%token PARS_DISTINCT_TOKEN
%token PARS_FROM_TOKEN
%token PARS_WHERE_TOKEN
%token PARS_FOR_TOKEN
%token PARS_DDOT_TOKEN
%token PARS_READ_TOKEN
%token PARS_ORDER_TOKEN
%token PARS_BY_TOKEN
%token PARS_ASC_TOKEN
%token PARS_DESC_TOKEN
%token PARS_INSERT_TOKEN
%token PARS_INTO_TOKEN
%token PARS_VALUES_TOKEN
%token PARS_UPDATE_TOKEN
%token PARS_SET_TOKEN
%token PARS_DELETE_TOKEN
%token PARS_CURRENT_TOKEN
%token PARS_OF_TOKEN
%token PARS_CREATE_TOKEN
%token PARS_TABLE_TOKEN
%token PARS_INDEX_TOKEN
%token PARS_UNIQUE_TOKEN
%token PARS_CLUSTERED_TOKEN
%token PARS_DOES_NOT_FIT_IN_MEM_TOKEN
%token PARS_ON_TOKEN
%token PARS_ASSIGN_TOKEN
%token PARS_DECLARE_TOKEN
%token PARS_CURSOR_TOKEN
%token PARS_SQL_TOKEN
%token PARS_OPEN_TOKEN
%token PARS_FETCH_TOKEN
%token PARS_CLOSE_TOKEN
%token PARS_NOTFOUND_TOKEN
%token PARS_TO_CHAR_TOKEN
%token PARS_TO_NUMBER_TOKEN
%token PARS_TO_BINARY_TOKEN
%token PARS_BINARY_TO_NUMBER_TOKEN
%token PARS_SUBSTR_TOKEN
%token PARS_REPLSTR_TOKEN
%token PARS_CONCAT_TOKEN
%token PARS_INSTR_TOKEN
%token PARS_LENGTH_TOKEN
%token PARS_SYSDATE_TOKEN
%token PARS_PRINTF_TOKEN
%token PARS_ASSERT_TOKEN
%token PARS_RND_TOKEN
%token PARS_RND_STR_TOKEN
%token PARS_ROW_PRINTF_TOKEN
%token PARS_COMMIT_TOKEN
%token PARS_ROLLBACK_TOKEN
%token PARS_WORK_TOKEN
%token PARS_UNSIGNED_TOKEN
%token PARS_EXIT_TOKEN
%token PARS_FUNCTION_TOKEN
%token PARS_LOCK_TOKEN
%token PARS_SHARE_TOKEN
%token PARS_MODE_TOKEN

%left PARS_AND_TOKEN PARS_OR_TOKEN
%left PARS_NOT_TOKEN
%left '=' '<' '>' PARS_GE_TOKEN PARS_LE_TOKEN
%left '-' '+'
%left '*' '/'
%left NEG         // negation--unary minus
%left '%'

// InnoDB Grammar Productions specifications
%%

top_statement
	: procedure_definition ';'

statement
	: stored_procedure_call
	| predefined_procedure_call ';'
	| while_statement ';'
	| for_statement ';'
	| exit_statement ';'
	| if_statement ';'
	| return_statement ';'
	| assignment_statement ';'
	| select_statement ';'
	| insert_statement ';'
	| row_printf_statement ';'
	| delete_statement_searched ';'
	| delete_statement_positioned ';'
	| update_statement_searched ';'
	| update_statement_positioned ';'
	| open_cursor_statement ';'
	| fetch_statement ';'
	| close_cursor_statement ';'
	| commit_statement ';'
	| rollback_statement ';'
	| create_table ';'
	| create_index ';'
;

statement_list
	: statement                  { $$ = que_node_list_add_last(nullptr, $1); }
	| statement_list statement   { $$ = que_node_list_add_last($1, $2);      }
;

exp
	: PARS_ID_TOKEN                                 { $$ = $1; }
	| function_name '(' exp_list ')'                { $$ = pars_func(ctx, $1, $3); }
	| PARS_INT_LIT		                            { $$ = $1; }
	| PARS_FLOAT_LIT	                            { $$ = $1; }
	| PARS_STR_LIT		                            { $$ = $1; }
	| PARS_FIXBINARY_LIT                            { $$ = $1; }
	| PARS_BLOB_LIT		                            { $$ = $1; }
	| PARS_NULL_LIT		                            { $$ = $1; }
	| PARS_SQL_TOKEN	                            { $$ = $1; }
	| exp '+' exp                                   { $$ = pars_op(ctx, '+', $1, $3);  }
	| exp '-' exp                                   { $$ = pars_op(ctx, '-', $1, $3);  }
	| exp '*' exp                                   { $$ = pars_op(ctx, '*', $1, $3);  }
	| exp '/' exp                                   { $$ = pars_op(ctx, '/', $1, $3);  }
	| '-' exp %prec NEG                             { $$ = pars_op(ctx, '-', $2, nullptr);  }
	| '(' exp ')'                                   { $$ = $2;  }
	| exp '=' exp		                            { $$ = pars_op(ctx, '=', $1, $3); }
	| exp '<' exp		                            { $$ = pars_op(ctx, '<', $1, $3); }
	| exp '>' exp		                            { $$ = pars_op(ctx, '>', $1, $3); }
	| exp PARS_GE_TOKEN exp	                        { $$ = pars_op(ctx, PARS_GE_TOKEN, $1, $3); }
	| exp PARS_LE_TOKEN exp	                        { $$ = pars_op(ctx, PARS_LE_TOKEN, $1, $3); }
	| exp PARS_NE_TOKEN exp	                        { $$ = pars_op(ctx, PARS_NE_TOKEN, $1, $3); }
	| exp PARS_AND_TOKEN exp                        { $$ = pars_op(ctx, PARS_AND_TOKEN, $1, $3); }
	| exp PARS_OR_TOKEN exp	                        { $$ = pars_op(ctx, PARS_OR_TOKEN, $1, $3); }
	| PARS_NOT_TOKEN exp	                        { $$ = pars_op(ctx, PARS_NOT_TOKEN, $2, nullptr); }
	| PARS_ID_TOKEN '%' PARS_NOTFOUND_TOKEN         { $$ = pars_op(ctx, PARS_NOTFOUND_TOKEN, $1, nullptr); }
	| PARS_SQL_TOKEN '%' PARS_NOTFOUND_TOKEN        { $$ = pars_op(ctx, PARS_NOTFOUND_TOKEN, $1, nullptr); }
;

function_name
	: PARS_TO_CHAR_TOKEN	       { $$ = &ctx->system->pars_to_char_token; }
	| PARS_TO_NUMBER_TOKEN	       { $$ = &ctx->system->pars_to_number_token; }
	| PARS_TO_BINARY_TOKEN	       { $$ = &ctx->system->pars_to_binary_token; }
	| PARS_BINARY_TO_NUMBER_TOKEN  { $$ = &ctx->system->pars_binary_to_number_token; }
	| PARS_SUBSTR_TOKEN            { $$ = &ctx->system->pars_substr_token; }
	| PARS_CONCAT_TOKEN            { $$ = &ctx->system->pars_concat_token; }
	| PARS_INSTR_TOKEN             { $$ = &ctx->system->pars_instr_token; }
	| PARS_LENGTH_TOKEN            { $$ = &ctx->system->pars_length_token; }
	| PARS_SYSDATE_TOKEN           { $$ = &ctx->system->pars_sysdate_token; }
	| PARS_RND_TOKEN	           { $$ = &ctx->system->pars_rnd_token; }
	| PARS_RND_STR_TOKEN           { $$ = &ctx->system->pars_rnd_str_token; }
;

question_mark_list
	:
	| '?'
	| question_mark_list ',' '?'
;

stored_procedure_call
	: '{' PARS_ID_TOKEN '(' question_mark_list ')' '}'     
	{ 
		$$ = pars_stored_procedure_call(ctx, static_cast<sym_node_t*>($2)); 
	}
;

predefined_procedure_call : predefined_procedure_name '(' exp_list ')'        { $$ = pars_procedure_call(ctx, $1, $3); }
;

predefined_procedure_name
	: PARS_REPLSTR_TOKEN	      { $$ = &ctx->system->pars_replstr_token; }
	| PARS_PRINTF_TOKEN	          { $$ = &ctx->system->pars_printf_token;  }
	| PARS_ASSERT_TOKEN	          { $$ = &ctx->system->pars_assert_token;  }
;

user_function_call : PARS_ID_TOKEN '(' ')'         { $$ = $1; }
;

table_list
	: PARS_ID_TOKEN                   { $$ = que_node_list_add_last(nullptr, $1); }
	| table_list ',' PARS_ID_TOKEN    { $$ = que_node_list_add_last($1, $3);      }
;

variable_list
	:                                        { $$ = nullptr; }
	| PARS_ID_TOKEN                          { $$ = que_node_list_add_last(nullptr, $1); }
	| variable_list ',' PARS_ID_TOKEN        { $$ = que_node_list_add_last($1, $3); }
;

exp_list
	:                        { $$ = nullptr; }
	| exp			         { $$ = que_node_list_add_last(nullptr, $1); }
	| exp_list ',' exp       { $$ = que_node_list_add_last($1, $3); }
;

select_item
	: exp  
	{  
		$$ = $1; 
	}
	
	| PARS_COUNT_TOKEN '(' '*' ')' 
	{ 
		$$ = pars_func(ctx, &ctx->system->pars_count_token, que_node_list_add_last(nullptr, sym_tab_add_int_lit( ctx->sym_tab, 1))); 
	}
	
	| PARS_COUNT_TOKEN '(' PARS_DISTINCT_TOKEN PARS_ID_TOKEN ')' 
	{ 
		$$ = pars_func(ctx, &ctx->system->pars_count_token, que_node_list_add_last(nullptr, pars_func(ctx, &ctx->system->pars_distinct_token, que_node_list_add_last( nullptr, $4)))); 
	}
	
	| PARS_SUM_TOKEN '(' exp ')' 
	{
		$$ = pars_func(ctx, &ctx->system->pars_sum_token, que_node_list_add_last(nullptr, $3));
	}
;

select_item_list
	:                                   { $$ = nullptr; }
	| select_item		                { $$ = que_node_list_add_last(nullptr, $1); }
	| select_item_list ',' select_item  { $$ = que_node_list_add_last($1, $3); }
;

select_list
	: '*'                                               { $$ = pars_select_list(ctx, &ctx->system->pars_star_denoter, nullptr);       }
	| select_item_list PARS_INTO_TOKEN variable_list    { $$ = pars_select_list(ctx, $1, static_cast<sym_node_t*>($3));  }
	| select_item_list                                  { $$ = pars_select_list(ctx, $1, nullptr);                       }
;

search_condition
	:                           { $$ = nullptr; }
	| PARS_WHERE_TOKEN exp      { $$ = $2;      }
;

for_update_clause
	:                                       { $$ = nullptr; }
	| PARS_FOR_TOKEN PARS_UPDATE_TOKEN      { $$ = &ctx->system->pars_update_token; }
;

lock_shared_clause
	:                                                                      { $$ = nullptr; }
	| PARS_LOCK_TOKEN PARS_IN_TOKEN PARS_SHARE_TOKEN PARS_MODE_TOKEN       { $$ = &ctx->system->pars_share_token; }
;

order_direction
	:                 { $$ = &ctx->system->pars_asc_token; }
	| PARS_ASC_TOKEN  { $$ = &ctx->system->pars_asc_token; }
	| PARS_DESC_TOKEN { $$ = &ctx->system->pars_desc_token; }
;

order_by_clause
	:                                                                  { $$ = nullptr; }
	| PARS_ORDER_TOKEN PARS_BY_TOKEN PARS_ID_TOKEN order_direction     { $$ = pars_order_by(ctx, static_cast<sym_node_t*>($3), static_cast<pars_res_word_t*>($4)); }
;

select_statement
	: 	PARS_SELECT_TOKEN select_list
		PARS_FROM_TOKEN   table_list
		search_condition
		for_update_clause
		lock_shared_clause
		order_by_clause 
	{ 
		$$ = pars_select_statement(
			ctx, 
			static_cast<sel_node_t*>($2), 
			static_cast<sym_node_t*>($4), 
			static_cast<que_node_t*>($5), 
			static_cast<pars_res_word_t*>($6), 
			static_cast<pars_res_word_t*>($7), 
			static_cast<order_node_t*>($8)
		); 
	}
;

insert_statement_start : PARS_INSERT_TOKEN PARS_INTO_TOKEN PARS_ID_TOKEN         { $$ = $3; }
;

insert_statement
	: insert_statement_start PARS_VALUES_TOKEN '(' exp_list ')' 
	{ 
		$$ = pars_insert_statement( ctx, static_cast<sym_node_t*>($1), $4, nullptr); 
	}
	
	| insert_statement_start select_statement 
	{ 
		$$ = pars_insert_statement( ctx, static_cast<sym_node_t*>($1), nullptr, static_cast<sel_node_t*>($2)); 
	}
;

column_assignment
	: PARS_ID_TOKEN '=' exp	
	{ 
		$$ = pars_column_assignment( ctx, static_cast<sym_node_t*>($1), $3); 
	}
;

column_assignment_list
	: column_assignment                                { $$ = que_node_list_add_last(nullptr, $1); }
	| column_assignment_list ',' column_assignment     { $$ = que_node_list_add_last($1, $3);      }
;

cursor_positioned
	: PARS_WHERE_TOKEN PARS_CURRENT_TOKEN PARS_OF_TOKEN PARS_ID_TOKEN     { $$ = $4; }
;

update_statement_start
	: PARS_UPDATE_TOKEN PARS_ID_TOKEN PARS_SET_TOKEN column_assignment_list 
	{ 
		$$ = pars_update_statement_start(
			ctx, 
			false, 
			static_cast<sym_node_t*>($2), 
			static_cast<col_assign_node_t*>($4)
		); 
	}
;

update_statement_searched
	: update_statement_start search_condition   
	{ 
		$$ = pars_update_statement(ctx, static_cast<upd_node_t*>($1), nullptr, static_cast<que_node_t*>($2)); 
	}
;

update_statement_positioned
	: update_statement_start cursor_positioned 
	{ 
		$$ = pars_update_statement(ctx, static_cast<upd_node_t*>($1), static_cast<sym_node_t*>($2), nullptr); 
	}
;

delete_statement_start
	: PARS_DELETE_TOKEN PARS_FROM_TOKEN PARS_ID_TOKEN 
	{ 
		$$ = pars_update_statement_start(ctx, true, static_cast<sym_node_t*>($3), nullptr); 
	}
;

delete_statement_searched
	: delete_statement_start search_condition 
	{ 
		$$ = pars_update_statement(ctx, static_cast<upd_node_t*>($1), nullptr, static_cast<que_node_t*>($2)); 
	}
;

delete_statement_positioned
	: delete_statement_start cursor_positioned 
	{ 
		$$ = pars_update_statement(ctx, static_cast<upd_node_t*>($1), static_cast<sym_node_t*>($2), nullptr); 
	}
;

assignment_statement
	: PARS_ID_TOKEN PARS_ASSIGN_TOKEN exp 
	{ 
		$$ = pars_assignment_statement(ctx, static_cast<sym_node_t*>($1), static_cast<que_node_t*>($3)); 
	}
;

row_printf_statement
	: PARS_ROW_PRINTF_TOKEN select_statement 
	{ 
		$$ = pars_row_printf_statement(ctx, static_cast<sel_node_t*>($2)); 
	}
;

elsif_element
	: PARS_ELSIF_TOKEN exp PARS_THEN_TOKEN statement_list
	{ 
		$$ = pars_elsif_element(ctx, $2, $4); 
	}
;

elsif_list
	: elsif_element 
	{ 
		$$ = que_node_list_add_last(nullptr, $1); 
	}
	
	| elsif_list elsif_element 
	{ 
		$$ = que_node_list_add_last($1, $2); 
	}
;

else_part
	:                                  { $$ = nullptr; }
	| PARS_ELSE_TOKEN statement_list   { $$ = $2; }
	| elsif_list                       { $$ = $1; }
;

if_statement
	: 	PARS_IF_TOKEN exp PARS_THEN_TOKEN 
			statement_list	
  			else_part
		PARS_END_TOKEN PARS_IF_TOKEN
	{ 
		$$ = pars_if_statement(ctx, $2, $4, $5); 
	}
;

while_statement
	: PARS_WHILE_TOKEN exp PARS_LOOP_TOKEN statement_list PARS_END_TOKEN PARS_LOOP_TOKEN 
	{ 
		$$ = pars_while_statement(ctx, $2, $4); 
	}
;

for_statement
:
	PARS_FOR_TOKEN PARS_ID_TOKEN PARS_IN_TOKEN
	exp PARS_DDOT_TOKEN exp
	PARS_LOOP_TOKEN statement_list
	PARS_END_TOKEN PARS_LOOP_TOKEN
				{ $$ = pars_for_statement(ctx, static_cast<sym_node_t*>($2), $4, $6, $8); } ;



exit_statement : PARS_EXIT_TOKEN        { $$ = pars_exit_statement(ctx); }
;


return_statement : PARS_RETURN_TOKEN	   { $$ = pars_return_statement(ctx); }
;

open_cursor_statement 
	: PARS_OPEN_TOKEN PARS_ID_TOKEN 
	{ 
		$$ = pars_open_statement(ctx, ROW_SEL_OPEN_CURSOR, static_cast<sym_node_t*>($2)); 
	}
;

close_cursor_statement
	: PARS_CLOSE_TOKEN PARS_ID_TOKEN 
	{ 
		$$ = pars_open_statement(ctx, ROW_SEL_CLOSE_CURSOR, static_cast<sym_node_t*>($2)); 
	}
;

fetch_statement
	: PARS_FETCH_TOKEN PARS_ID_TOKEN PARS_INTO_TOKEN variable_list
    { 
		$$ = pars_fetch_statement( ctx, static_cast<sym_node_t*>($2), static_cast<sym_node_t*>($4), nullptr); 
	}
    
	| PARS_FETCH_TOKEN PARS_ID_TOKEN PARS_INTO_TOKEN user_function_call
    { 
		$$ = pars_fetch_statement( ctx, static_cast<sym_node_t*>($2), nullptr, static_cast<sym_node_t*>($4)); 
	}
;

column_def
	: PARS_ID_TOKEN type_name opt_column_len opt_unsigned opt_not_null
    { 
		$$ = pars_column_def( 
			ctx, 
			static_cast<sym_node_t*>($1), 
			static_cast<pars_res_word_t*>($2), 
			static_cast<sym_node_t*>($3), 
			$4, 
			$5
		); 
	}
;

column_def_list
:
	column_def { $$ = que_node_list_add_last(nullptr, $1); }
	| column_def_list ',' column_def { $$ = que_node_list_add_last($1, $3); }
;

opt_column_len
	:                          { $$ = nullptr; }
	| '(' PARS_INT_LIT ')'     { $$ = $2; }
;

opt_unsigned
	:                          { $$ = nullptr; }
	| PARS_UNSIGNED_TOKEN      { $$ = &ctx->system->pars_int_token; /* pass any non-null poiner */ }
;

opt_not_null
	: {  $$ = nullptr; }
	
	| PARS_NOT_TOKEN PARS_NULL_LIT 
	{ 
		// pass any non-null poiner
		$$ = &ctx->system->pars_int_token; 
	}
;

not_fit_in_memory
	: { $$ = nullptr; }
	
	| PARS_DOES_NOT_FIT_IN_MEM_TOKEN 
	{ 
		// pass any non-nullptr pointer
		$$ = &ctx->system->pars_int_token;
	}
;

create_table
	:  PARS_CREATE_TOKEN PARS_TABLE_TOKEN PARS_ID_TOKEN 
	   '(' column_def_list ')'
	   not_fit_in_memory 
	{ 
		$$ = pars_create_table(
			ctx, 
			static_cast<sym_node_t*>($3), 
			static_cast<sym_node_t*>($5), 
			$7
		); 
	}
;

column_list
	: PARS_ID_TOKEN                 { $$ = que_node_list_add_last(nullptr, $1); }
	| column_list ',' PARS_ID_TOKEN { $$ = que_node_list_add_last($1, $3); }
;

unique_def
	:                      { $$ = nullptr; }
	| PARS_UNIQUE_TOKEN    { $$ = &ctx->system->pars_unique_token; }
;

clustered_def
	:                       { $$ = nullptr; }
	| PARS_CLUSTERED_TOKEN  { $$ = &ctx->system->pars_clustered_token; }
;

create_index
	: 	PARS_CREATE_TOKEN unique_def 
			clustered_def
		PARS_INDEX_TOKEN PARS_ID_TOKEN 
		PARS_ON_TOKEN    PARS_ID_TOKEN '(' column_list ')' 
	{ 
		$$ = pars_create_index(
			ctx, 
			static_cast<pars_res_word_t*>($2), 
			static_cast<pars_res_word_t*>($3), 
			static_cast<sym_node_t*>($5), 
			static_cast<sym_node_t*>($7), 
			static_cast<sym_node_t*>($9)
		); 
	}
;

commit_statement : PARS_COMMIT_TOKEN PARS_WORK_TOKEN          { $$ = pars_commit_statement(ctx); } 
;

rollback_statement : PARS_ROLLBACK_TOKEN PARS_WORK_TOKEN      { $$ = pars_rollback_statement(ctx); }
;

type_name
	: PARS_INT_TOKEN        { $$ = &ctx->system->pars_int_token;    }
	| PARS_INTEGER_TOKEN    { $$ = &ctx->system->pars_int_token;    }
	| PARS_CHAR_TOKEN       { $$ = &ctx->system->pars_char_token;   }
	| PARS_BINARY_TOKEN     { $$ = &ctx->system->pars_binary_token; }
	| PARS_BLOB_TOKEN       { $$ = &ctx->system->pars_blob_token;   }
;

parameter_declaration
	: PARS_ID_TOKEN PARS_IN_TOKEN type_name 
	{ 
		$$ = pars_parameter_declaration(ctx, static_cast<sym_node_t*>($1), PARS_INPUT, static_cast<pars_res_word_t*>($3)); 
	}
    
	| PARS_ID_TOKEN PARS_OUT_TOKEN type_name { 
		$$ = pars_parameter_declaration(ctx, static_cast<sym_node_t*>($1), PARS_OUTPUT, static_cast<pars_res_word_t*>($3)); 
	}
;

parameter_declaration_list
	:                                                      { $$ = nullptr; }
	| parameter_declaration                                { $$ = que_node_list_add_last(nullptr, $1); }
	| parameter_declaration_list ',' parameter_declaration { $$ = que_node_list_add_last($1, $3); }
;

variable_declaration 
	: PARS_ID_TOKEN type_name ';' 
	{ 
		$$ = pars_variable_declaration(ctx, static_cast<sym_node_t*>($1), static_cast<pars_res_word_t*>($2)); 
	}
;

variable_declaration_list
	:
	| variable_declaration
	| variable_declaration_list variable_declaration
;

cursor_declaration
	: PARS_DECLARE_TOKEN PARS_CURSOR_TOKEN PARS_ID_TOKEN PARS_IS_TOKEN select_statement ';' { 
		$$ = pars_cursor_declaration(ctx, static_cast<sym_node_t*>($3), static_cast<sel_node_t*>($5)); 
	}
;

function_declaration
	: PARS_DECLARE_TOKEN PARS_FUNCTION_TOKEN PARS_ID_TOKEN ';' { 
		$$ = pars_function_declaration(ctx, static_cast<sym_node_t*>($3)); 
	}
;

declaration
	: cursor_declaration
	| function_declaration
;

declaration_list
	:
	| declaration
	| declaration_list declaration
;

procedure_definition
	:	PARS_PROCEDURE_TOKEN PARS_ID_TOKEN '(' parameter_declaration_list ')' PARS_IS_TOKEN 
			variable_declaration_list
        	declaration_list
      	PARS_BEGIN_TOKEN
	        statement_list
      	PARS_END_TOKEN 
	{ 
		$$ = pars_procedure_definition(ctx, static_cast<sym_node_t*>($2), static_cast<sym_node_t*>($4), $10); 
	}
;

%%

/// @brief Release any resources used by the parser.
void pars_close(Parser_context* ctx) {
  pars_lexer_close(ctx);
}
