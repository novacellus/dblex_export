<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="xml" indent="yes"/>
    
    <!-- Use text mode to read CSV input -->
    <xsl:mode name="csv" on-no-match="shallow-copy"/>
    
    <!-- Main template -->
    <xsl:template name="csv-to-xml">
        <!-- Read and parse the CSV file -->
        <xsl:variable name="csv" select="unparsed-text('sgp_geo_enriched.csv', 'UTF-8')"/>
        <xsl:variable name="lines" select="tokenize($csv, '\\n')"/>
        <xsl:variable name="headers" select="tokenize($lines[1], ',')"/>
        
        <!-- Create root element -->
        <locations>
            <!-- Process each data line (skip header) -->
            <xsl:for-each select="$lines[position() > 1][normalize-space()]">
                <xsl:variable name="line" select="."/>
                <xsl:variable name="fields" select="tokenize($line, ',')"/>
                
                <location>
                    <settlement><xsl:value-of select="$fields[1]"/></settlement>
                    <region>
                        <abbreviation><xsl:value-of select="$fields[2]"/></abbreviation>
                        <xsl:if test="normalize-space($fields[6])">
                            <expanded_name><xsl:value-of select="$fields[6]"/></expanded_name>
                        </xsl:if>
                        <xsl:if test="normalize-space($fields[7])">
                            <regional_town><xsl:value-of select="$fields[7]"/></regional_town>
                        </xsl:if>
                    </region>
                    <xsl:if test="normalize-space($fields[4]) and normalize-space($fields[5])">
                        <coordinates>
                            <latitude><xsl:value-of select="$fields[4]"/></latitude>
                            <longitude><xsl:value-of select="$fields[5]"/></longitude>
                        </coordinates>
                    </xsl:if>
                    <original><xsl:value-of select="$fields[3]"/></original>
                </location>
            </xsl:for-each>
        </locations>
    </xsl:template>
    
</xsl:stylesheet>