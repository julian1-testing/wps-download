#!/bin/bash

# Bash script to submit an async wps job, poll and download the result, 
# uses curl, java, saxon, xmllint, xml, and xslt!

GEOSERVER_URL=http://geoserver-rc.aodn.org.au/geoserver/wps
WPS_JOB=wps-ts_timeseries.xml

[ -d tmp ] && rm tmp -rf
mkdir tmp

cat > tmp/extract-status-url.xsl << EOF
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:wps="http://www.opengis.net/wps/1.0.0"
    exclude-result-prefixes="xsl"
>
  <xsl:output method="text"/>

  <xsl:template match="wps:ExecuteResponse">
      <xsl:value-of select="./@statusLocation" />
  </xsl:template>
</xsl:stylesheet>
EOF

cat > tmp/extract-status.xsl << EOF
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:wps="http://www.opengis.net/wps/1.0.0"
    exclude-result-prefixes="xsl"
>
  <xsl:output method="text"/>

  <xsl:template match="wps:Status/wps:ProcessStarted">
      <xsl:text>started</xsl:text>
  </xsl:template>

  <xsl:template match="wps:Status/wps:ProcessSucceeded">
      <xsl:text>succeeded</xsl:text>
  </xsl:template>

  <xsl:template match="wps:Status/wps:ProcessFailed">
      <xsl:text>failed</xsl:text>
  </xsl:template>

  <xsl:template match="@*|node()">
      <xsl:apply-templates select="@*|node()"/>
  </xsl:template>
</xsl:stylesheet>
EOF

cat > tmp/extract-download-url.xsl << EOF
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:wps="http://www.opengis.net/wps/1.0.0"
    exclude-result-prefixes="xsl"
>
  <xsl:output method="text"/>

  <xsl:template match="wps:Output/wps:Reference">
      <xsl:value-of select="./@href" />
  </xsl:template>

  <xsl:template match="@*|node()">
      <xsl:apply-templates select="@*|node()"/>
  </xsl:template>
</xsl:stylesheet>
EOF


# submit wps job
echo "submitting wps job, $WPS_JOB to $GEOSERVER_URL"

curl -s \
  --data @"$WPS_JOB" \
  --header "Expect:" \
  --header "Content-Type: application/xml" \
  $GEOSERVER_URL \
  | xmllint --format - \
  > tmp/1.xml \
  || exit 123

# extract status
STATUS_URL=$( java -jar ./saxon-he.jar tmp/1.xml tmp/extract-status-url.xsl )
echo "STATUS_URL $STATUS_URL"

# poll status until finished
STATUS="started"
while [ "$STATUS" = started ]; do

  curl -s \
    "$STATUS_URL" \
    | xmllint --format - \
    > tmp/2.xml \
    || exit 123

  STATUS=$( java -jar ./saxon-he.jar tmp/2.xml tmp/extract-status.xsl )
  echo "status is, '$STATUS'"

  if [ "$STATUS" = failed ]; then
    exit 123
  fi

  sleep 1;
done

# extract download url
DOWNLOAD_URL=$( java -jar ./saxon-he.jar tmp/2.xml tmp/extract-download-url.xsl )

# download
echo "DOWNLOAD_URL $DOWNLOAD_URL"
echo "downloading to tmp/result.zip"
curl -s "$DOWNLOAD_URL"  > tmp/result.zip


