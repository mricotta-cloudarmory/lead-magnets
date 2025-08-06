# Lead Magnets

Lead magnets are downloadable packages used by our lead gen forms.  Traditionally these have been "whitepapers" but they can be packages or executables as well.

## Setup

To set up a lead magnet on the corporate website, follow these steps:

1. Prepare your lead magnet as a single downloadable file (.zip, .pdf, .png, .jpg.  No docx files, no unzipped folders, no executables/scripts that could be perceived as malicious).
2. Log into https://www.cloudarmory.com/wp-admin
3. If you have hosted your package externally (ie. S3), get your package's public URL.  Otherwise you can follow these steps:
	1. Go to "Media" on the left navigation
	2. Upoad your package
	3. Upon upload completion, select your upload from the media panel and you'll see the "File URL" on the right sidebar.
4. Visit "Pages" and select the page you want to add a magnet to.
5. Scroll down to "Add New Custom Field" and in the dropdown, select "Whitepaper" then paste your package URL (per step 3 above)
6. Confirm on the right-sidebar that your page has the "Lead Gen" template assigned.
7. Publish / Update

*Atop the page you'll see the "permalink" which you can click to visit the page directly*

### Lead Gen Forms

If you have specific language you want to drive for a specific keyword on your page, use the "Lead Gen" post type by following the below instructions.  Doing this will overwrite the content for any page that uses the "Lead Gen" template with whatever has been written to a respective matching "Lead Gen" post type.
*For example, let's say you're targeting "PCI-DSS" leads and you want to focus specifically on "PayFacs" and broad-keyword-matches (ie. "PCI for PayFacs").*

1. Log into https://www.cloudarmory.com/wp-admin
2. On the left sidebar, select "Lead Gen"
3. Click "Add New Post" (or select the one you want to edit)
4. Give the post a name that's a partial match for your long-tail-keyword match.  For example, "PayFac" matches "PayFacs" and "PCI for PayFacs".
5. Fill out the body, then scroll down and fill out the "Excert" section, which serves as the page's header.  You are not required to use both fields, if you only want to override one, simply leave the other blank.  *This information will override the page content for any targeted page that inherits the "Lead Gen" template*
6. Add a whitepaper, if you'd like, using the Custom Fields.  Follow step 5 from the "Setup" instructions atop this page.
7. Publish / Update

*Atop the page you'll see the "permalink" which you can click to visit the page directly however, these permalinks aren't shared across the site.*
*Instead what you'll use are variable URL parameters driven by Google Ads with the "service" and "keyword" parameters.*
*In this example it would be visible on: https://www.cloudarmory.com/managed-soc1-soc2-devsecops?service=PayFac*

## Kits (compliance)

Our compliance kits are primarily managed via Google Drive at the following link.  Google sheets and google docs retain version history, which is a safer method of version control than Github for retaining spreadsheet functionality, especially since spreadsheet files aren't readable in the same format as Git requires.
https://drive.google.com/drive/folders/1KszvAlJSVBdgs7lwRnrPch1qlQL0zBev?usp=drive_link

To build a kit, follow these steps AFTER you run a Git Pull (always Git pull before you start work):

1. Generate all policy rules and evidence types.  AI can help with that or you can find the source file like we did with PCI.  You can do this in json or csv format as follows below (copy the SOC1 or SOC2 files if you want a template)
	1. JSON: Rule ID as the row key (ie. { R1.1: {}, R1.1.1: {}, A1.1: {}, A1.2: {}}.  Then, within each rule:
		1. key:value pair of "rule":"your rule language goes here",
		2. key:value pair of "type":"Item|Category" *If this is a testable item, call it an Item but if it is a top-level category like 1.1, call it "Category"*
		3. key:value pair of "evidence":["array","of","evidence"]
		4. key:bool pair of "required":true|false
	2. CSV:
		1. Rule ID (col 1)
		2. Rule language
		3. Evidence;semi-colon;delimited;or;"Category"
		4. Requred "Yes" or "No"
2. Use the converter script in the "scripts" directory to covert to the other format (see README.md in that directory)
3. Clone a workbook from another kit in Google Drive.  The workbook framework is the same across all auditable security frameworks.
4. Import the CSV formatted ruleset file into the "Rules" tab, via the built-in import function, replacing the current sheet.
5. Now review your tabs, verify for completeness
6. Clone the README.docx from another kit, update the language and then export it as PDF
7. Download the kit package, remove the docx file, then zip it and upload it to your lead magnets directory.  Follow the Setup & Lead Gen steps above.
8. Commit and push your changes

#### NOTE: I would like to move kit storage to S3 via Jenkins pipeline build (git actions).  I want it automated (ci/cd), so Jenkins should pull on Github actions (push/merge) and upload zip files to S3 on a static URL (not dynamic, we wan't the URL to be the same when the file is uploaded and overwrites the old one)


## Scripts / Executables

Security scripts like agent installers are an excellent method for lead generation.  Freemium model scripts provide a way to gain access into client systems.  For example, if we offered ThreatDown for free and drove campaigns for free installation, we'd have immediate internal system visualization of company computers and servers.

For something like an agent installer, the best recommended approach would be to write a batch or bash script which performs the installer only after first prompting the user to provide their name, phone, and email and posting that information remotely to an API of our ownership OR by providing an email and registration code for API verification (also by post).  Ideally the entire thing would be compiled or the script would clone the actual agent installer from a remote location (is. this repository or S3).  If you intend to host it on this repository use the "cdn" directory.

## Agents

Agent scripts provide a way for clients to perform their own initial investigation and remediation.  If an agent script can also lead a customer down the pathway of contacting Cloud Armory for assistance, that's an advanced lead generation method.  The risk there is that agent scripts are generally written in markdown language, which makes them easily readable and easily altered to remove us from the fold.