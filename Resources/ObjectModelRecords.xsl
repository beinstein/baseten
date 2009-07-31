<?xml version="1.0" encoding="UTF-8" ?>
<!--
 ObjectModelRecords.xsl
 BaseTen
 
 Copyright (C) 2009 Marko Karppinen & Co. LLC.
 
 Before using this software, please review the available licensing options
 by visiting http://basetenframework.org/licensing/ or by contacting
 us at sales@karppinen.fi. Without an additional license, this software
 may be distributed only in compliance with the GNU General Public License.
 
 
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License, version 2.0,
 as published by the Free Software Foundation.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 
 $Id$
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output encoding="UTF-8" indent="no" method="text" />

    <xsl:template match="/">
        <xsl:text>graph G {&#10;</xsl:text>
        <xsl:text>&#9;rankdir="LR"&#10;</xsl:text>
        <xsl:text>&#9;node [shape = record, style = rounded];&#10;</xsl:text>
        <xsl:apply-templates select="//entity" />
        
        <xsl:text>&#9;edge [];&#10;</xsl:text>
        <xsl:apply-templates select=".//relationship" mode="edge" />
        <xsl:text>}&#10;</xsl:text>
    </xsl:template>


    <xsl:template match="//entity">
        <xsl:text>&#9;</xsl:text>
        <xsl:value-of select="./@id" />
        <xsl:text> [label = "</xsl:text>

        <xsl:value-of select="./schemaName" />
        <xsl:text>.</xsl:text>
        <xsl:value-of select="./name" />
        
        <xsl:apply-templates select="./attributes" />
        <xsl:apply-templates select="./relationships" />
        
        <xsl:text>"];&#10;</xsl:text>
    </xsl:template>


    <xsl:template match="//attributes">
        <xsl:comment>Attributes</xsl:comment>
        <xsl:apply-templates select="./attribute [not (@isInherited = 'true')]" />
    </xsl:template>


    <xsl:template match="//relationships">
        <xsl:comment>Relationships</xsl:comment>
        <xsl:apply-templates select="./relationship" />
    </xsl:template>


    <xsl:template match="//attribute">
        <xsl:text>|</xsl:text>
        <xsl:value-of select="./name" />
        <xsl:text> </xsl:text>
        <xsl:value-of select="./type" />
    </xsl:template>


    <xsl:template match="//relationship">
        <xsl:text>|&lt;</xsl:text>
        <xsl:value-of select="./name" />
        <xsl:text>&gt; </xsl:text>
        <xsl:value-of select="./name" />
    </xsl:template>

    
    <xsl:template match="//relationship" mode="edge">
        <xsl:variable name="entityName" select="../../@id" />
        <xsl:variable name="relName" select="./name" />
        <xsl:variable name="inverse" select="preceding::relationship [./target = $entityName and ./inverseRelationship = $relName][1]" />        
        <xsl:if test="$inverse">
            <xsl:text>&#9;</xsl:text>
            <xsl:value-of select="../../@id" />
            <xsl:text>:</xsl:text>
            <xsl:value-of select="./name" />
            <xsl:text> -- </xsl:text>
            <xsl:value-of select="./target" />
            <xsl:text>:</xsl:text>
            <xsl:value-of select="./inverseRelationship" />
            
            <xsl:text> [arrowhead = normal</xsl:text>
            <xsl:if test="./targetType = 'many'">
                <xsl:text>normal</xsl:text>
            </xsl:if>
            <xsl:text>, arrowtail = normal</xsl:text>
            <xsl:if test="$inverse/targetType = 'many'">
                <xsl:text>normal</xsl:text>
            </xsl:if>
            
            <xsl:text>];&#10;</xsl:text>
        </xsl:if>
    </xsl:template>
</xsl:stylesheet>
