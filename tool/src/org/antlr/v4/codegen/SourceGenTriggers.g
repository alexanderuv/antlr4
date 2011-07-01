tree grammar SourceGenTriggers;
options {
	language     = Java;
	tokenVocab   = ANTLRParser;
	ASTLabelType = GrammarAST;
}

@header {
package org.antlr.v4.codegen;
import org.antlr.v4.misc.Utils;
import org.antlr.v4.codegen.model.*;
import org.antlr.v4.tool.*;
import java.util.Collections;
import java.util.Map;
import java.util.HashMap;
}

@members {
	public OutputModelFactory factory;
    public SourceGenTriggers(TreeNodeStream input, OutputModelFactory factory) {
    	this(input);
    	this.factory = factory;
    }
}

dummy : block[null, null] ;

block[GrammarAST label, GrammarAST ebnfRoot] returns [List<SrcOp> omos]
    :	^(	blk=BLOCK (^(OPTIONS .+))?
			{List<SrcOp> alts = new ArrayList<SrcOp>();}
    		( alternative {alts.addAll($alternative.omos);} )+
    	)
    	{
    	if ( alts.size()==1 && ebnfRoot==null) return alts;
    	if ( ebnfRoot==null ) {
    	    $omos = factory.getChoiceBlock((BlockAST)$blk, alts);
    	}
    	else {
    	    $omos = factory.getEBNFBlock($ebnfRoot, alts);
    	}
    	}
    ;

alternative returns [List<SrcOp> omos]
@init {
	List<SrcOp> elems = new ArrayList<SrcOp>();
	// set alt if outer ALT only
	if ( inContext("RULE BLOCK") && ((AltAST)$start).alt!=null ) factory.setCurrentAlt(((AltAST)$start).alt);
}
    :	^(ALT_REWRITE a=alternative {$omos=$a.omos;} (rewrite {DefaultOutputModelFactory.list($omos, $rewrite.omos);} | ))
    |	^(ALT EPSILON) {$omos = factory.epsilon();}
    |   ^( ALT ( element {if ($element.omos!=null) elems.addAll($element.omos);} )+ )
    	{$omos = factory.alternative(elems);}
    ;

element returns [List<SrcOp> omos]
	:	labeledElement					{$omos = $labeledElement.omos;}
	|	atom[null]						{$omos = $atom.omos;}
	|	ebnf							{$omos = $ebnf.omos;}
	|   ACTION							{$omos = factory.action($ACTION);}
	|   FORCED_ACTION					{$omos = factory.forcedAction($FORCED_ACTION);}
	|   SEMPRED							{$omos = factory.sempred($SEMPRED);}
	|	GATED_SEMPRED
	|	treeSpec
	;

labeledElement returns [List<SrcOp> omos]
	:	^(ASSIGN ID atom[$ID] )				{$omos = $atom.omos;}
	|	^(ASSIGN ID block[$ID,null])		{$omos = $block.omos;}
	|	^(PLUS_ASSIGN ID atom[$ID])			{$omos = $atom.omos;}
	|	^(PLUS_ASSIGN ID block[$ID,null])	{$omos = $block.omos;}
	;

treeSpec returns [SrcOp omo]
    : ^(TREE_BEGIN  (e=element )+)
    ;

ebnf returns [List<SrcOp> omos]
	:	^(astBlockSuffix block[null,null])
	|	^(OPTIONAL block[null,$OPTIONAL])	{$omos = $block.omos;}
	|	^(CLOSURE block[null,$CLOSURE])		{$omos = $block.omos;}
	|	^(POSITIVE_CLOSURE block[null,$POSITIVE_CLOSURE])
										    {$omos = $block.omos;}
	| 	block[null, null]					{$omos = $block.omos;}
    ;

astBlockSuffix
    : ROOT
    | IMPLIES
    | BANG
    ;

// TODO: combine ROOT/BANG into one then just make new op ref'ing return value of atom/terminal...
// TODO: same for NOT
atom[GrammarAST label] returns [List<SrcOp> omos]
	:	^(ROOT notSet[label])
	|	^(BANG notSet[label])		{$omos = $notSet.omos;}
	|	notSet[label]
	|	range[label]				{$omos = $range.omos;}
	|	^(DOT ID terminal[label])
	|	^(DOT ID ruleref[label])
    |	^(WILDCARD .)
    |	WILDCARD
    |	^(ROOT terminal[label])		{$omos = factory.rootToken($terminal.omos);}
    |	^(BANG terminal[label])		{$omos = $terminal.omos;}
    |   terminal[label]				{$omos = $terminal.omos;}
    |	^(ROOT ruleref[label])		{$omos = factory.rootRule($ruleref.omos);}
    |	^(BANG ruleref[label])		{$omos = $ruleref.omos;}
    |   ruleref[label]				{$omos = $ruleref.omos;}
    ;

notSet[GrammarAST label] returns [List<SrcOp> omos]
    : ^(NOT terminal[label])
    | ^(NOT block[label,null])
    ;

ruleref[GrammarAST label] returns [List<SrcOp> omos]
    :	^(RULE_REF ARG_ACTION?)		{$omos = factory.ruleRef($RULE_REF, $label, $ARG_ACTION);}
    ;

range[GrammarAST label] returns [List<SrcOp> omos]
    :	^(RANGE a=STRING_LITERAL b=STRING_LITERAL)
    ;

terminal[GrammarAST label] returns [List<SrcOp> omos]
    :  ^(STRING_LITERAL .)			{$omos = factory.stringRef($STRING_LITERAL, $label);}
    |	STRING_LITERAL				{$omos = factory.stringRef($STRING_LITERAL, $label);}
    |	^(TOKEN_REF ARG_ACTION .)	{$omos = factory.tokenRef($TOKEN_REF, $label, $ARG_ACTION);}
    |	^(TOKEN_REF .)				{$omos = factory.tokenRef($TOKEN_REF, $label, null);}
    |	TOKEN_REF					{$omos = factory.tokenRef($TOKEN_REF, $label, null);}
    ;

elementOptions
    :	^(ELEMENT_OPTIONS elementOption+)
    ;

elementOption
    :	ID
    |   ^(ASSIGN ID ID)
    |   ^(ASSIGN ID STRING_LITERAL)
    ;

// R E W R I T E  S T U F F

rewrite returns [List<SrcOp> omos]
	:	predicatedRewrite* nakedRewrite 	{$omos = nakedRewrite.omos;}
	;

predicatedRewrite returns [List<SrcOp> omos]
	:	^(ST_RESULT SEMPRED rewriteSTAlt)
	|	^(RESULT SEMPRED rewriteTreeAlt)
	;

nakedRewrite returns [List<SrcOp> omos]
	:	^(ST_RESULT rewriteSTAlt)
	|	^(RESULT rewriteTreeAlt)			{$omos = $rewriteTreeAlt.omos;}
	;

rewriteTreeAlt returns [List<SrcOp> omos]
    :	^(ALT rewriteTreeElement+)
    |	ETC
    |	EPSILON
    ;

rewriteTreeElement returns [List<SrcOp> omos]
	:	rewriteTreeAtom
	|	rewriteTree
	|   rewriteTreeEbnf
	;

rewriteTreeAtom returns [List<SrcOp> omos]
    :   ^(TOKEN_REF elementOptions ARG_ACTION)
    |   ^(TOKEN_REF elementOptions)
    |   ^(TOKEN_REF ARG_ACTION)
	|   TOKEN_REF							{$omos = factory.rewrite_tokenRef($TOKEN_REF);}
    |   RULE_REF							{$omos = factory.rewrite_ruleRef($TOKEN_REF);}
	|   ^(STRING_LITERAL elementOptions)
	|   STRING_LITERAL
	|   LABEL
	|	ACTION
	;

rewriteTreeEbnf returns [List<SrcOp> omos]
	:	^('?' ^(REWRITE_BLOCK rewriteTreeAlt))
	:	^('*' ^(REWRITE_BLOCK rewriteTreeAlt))
	;
	
rewriteTree returns [List<SrcOp> omos]
	:	^(TREE_BEGIN rewriteTreeAtom rewriteTreeElement* )
	;

rewriteSTAlt returns [List<SrcOp> omos]
    :	rewriteTemplate
    |	ETC
    |	EPSILON
    ;

rewriteTemplate returns [List<SrcOp> omos]
	:	^(TEMPLATE rewriteTemplateArgs? DOUBLE_QUOTE_STRING_LITERAL)
	|	^(TEMPLATE rewriteTemplateArgs? DOUBLE_ANGLE_STRING_LITERAL)
	|	rewriteTemplateRef
	|	rewriteIndirectTemplateHead
	|	ACTION
	;

rewriteTemplateRef returns [List<SrcOp> omos]
	:	^(TEMPLATE ID rewriteTemplateArgs?)
	;

rewriteIndirectTemplateHead returns [List<SrcOp> omos]
	:	^(TEMPLATE ACTION rewriteTemplateArgs?)
	;

rewriteTemplateArgs returns [List<SrcOp> omos]
	:	^(ARGLIST rewriteTemplateArg+)
	;

rewriteTemplateArg returns [List<SrcOp> omos]
	:   ^(ARG ID ACTION)
	;
