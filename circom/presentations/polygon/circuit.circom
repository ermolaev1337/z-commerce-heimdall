include "../../lib/metaData.circom";
include "../../lib/contentData.circom";
include "../../lib/checkRevocation.circom";

template PolygonPresentation(depth, revocationDepth, polygonSize) {
	/*
	*  Inputs
	*/
	// Meta
	signal input pathMeta[depth];
	signal input lemmaMeta[depth + 2];
	signal input meta[8]; //Fixed Size of meta attributes in each credential
	signal input signatureMeta[3];
	signal input pathRevocation[revocationDepth];
	signal input lemmaRevocation[revocationDepth + 2];
	signal input revocationLeaf;
	signal input signChallenge[3];
	signal input issuerPK[2];
	// Content
	signal input lemma[depth + 2];
	signal input location[2];
	/*
	* Public Inputs
	*/
	// Meta
	signal input challenge; //7
	signal input expiration; //8
	signal output type; //0
	signal output revocationRoot; //1
	signal output revocationRegistry; //2
	signal output revoked; //3
	signal output linkBack; //4
	signal output delegatable; //5
	// Content
	signal input path[depth]; // 9..12
	signal input vertx[polygonSize]; //13..62
	signal input verty[polygonSize]; //63..120

	signal output inbound; //6
	signal output out_challenge; //7
	signal output out_expiration; //8
	signal output out_path[depth]; //9...
	signal output poly_vertx[polygonSize]; //13
	signal output poly_verty[polygonSize];
	/*
	* Meta Calculations
	*/
	// Begin - Check Meta Integrity
	component checkMetaDataIntegrity = CheckMetaDataIntegrity(depth);

	checkMetaDataIntegrity.lemma[0] <== lemmaMeta[0];
	checkMetaDataIntegrity.lemma[depth + 1] <== lemmaMeta[depth + 1];
	checkMetaDataIntegrity.issuerPK[0] <== issuerPK[0];
	checkMetaDataIntegrity.issuerPK[1] <== issuerPK[1];

	checkMetaDataIntegrity.signature[0] <== signatureMeta[0];
	checkMetaDataIntegrity.signature[1] <== signatureMeta[1];
	checkMetaDataIntegrity.signature[2] <== signatureMeta[2];

	for(var i = 0; i < 8; i++) {
		checkMetaDataIntegrity.meta[i] <== meta[i];
	}

	for(var i = 0; i < depth; i++) {
		checkMetaDataIntegrity.path[i] <== pathMeta[i];
		checkMetaDataIntegrity.lemma[i + 1] <== lemmaMeta[i + 1];
	}
	revocationRegistry <== checkMetaDataIntegrity.revocationRegistry;
	// End - Check Meta Integrity

	type <== checkMetaDataIntegrity.type;
	// revocationRoot <== lemmaRevocation[revocationDepth + 1];
	delegatable <== checkMetaDataIntegrity.delegatable;

	// Begin - Check Expiration
	component checkExpiration = CheckExpiration();
	checkExpiration.expirationCredential <== checkMetaDataIntegrity.expiration;
	checkExpiration.expirationPresentation <== expiration;
	// End - Check Expiration

	// Begin - Check Revocation
	component checkRevocation = CheckRevocation(revocationDepth);
	checkRevocation.id <== checkMetaDataIntegrity.id;
	checkRevocation.revocationLeaf <== revocationLeaf;
	checkRevocation.lemma[0] <== lemmaRevocation[0];
	checkRevocation.lemma[revocationDepth + 1] <== lemmaRevocation[revocationDepth + 1];
	for(var i = 0; i < revocationDepth; i++) {
		checkRevocation.path[i] <== pathRevocation[i];
		checkRevocation.lemma[i + 1] <== lemmaRevocation[i + 1];
	}
	revocationRoot <== checkRevocation.revocationRoot;
	revoked <== checkRevocation.revoked;
	// End - Check Revocation

	//Begin - Link Back
	component getLinkBack = Link();
	getLinkBack.challenge <== challenge;
	getLinkBack.pk[0] <== issuerPK[0];
	getLinkBack.pk[1] <== issuerPK[1];
	linkBack <== getLinkBack.out;
	// End - Link Back

	//Begin - Holder Binding
	component checkHolderBinding = CheckHolderBinding();
	checkHolderBinding.signChallenge[0] <== signChallenge[0];
	checkHolderBinding.signChallenge[1] <== signChallenge[1];
	checkHolderBinding.signChallenge[2] <== signChallenge[2];
	checkHolderBinding.challenge <== challenge;
	checkHolderBinding.holderPK[0] <== checkMetaDataIntegrity.holderPK[0];
	checkHolderBinding.holderPK[1] <== checkMetaDataIntegrity.holderPK[1];
	//End - Holder Binding

	/*
	* Content Calculations
	*/
	component polygon = CheckPolygon(polygonSize, depth);

	for(var i = 0; i < polygonSize; i++) {
		polygon.vertx[i] <== vertx[i];
		polygon.verty[i] <== verty[i];
	}		

	polygon.lemma[0] <== lemma[0];
	polygon.lemma[depth + 1] <== lemma[depth + 1];

	for (var i = 0; i < depth; i++) {
		polygon.path[i] <== path[i];
		polygon.lemma[i + 1] <== lemma[i + 1];
	}	

	polygon.location[0] <== location[0];
	polygon.location[1] <== location[1];
	polygon.credentialRoot <== checkMetaDataIntegrity.credentialRoot;

	inbound <== polygon.inbound; //6
	challenge ==> out_challenge; //7 challenge
	expiration ==> out_expiration; //8 expiration
	//9,10,11,12 path
	for (var i = 0; i < depth; i++) {
		path[i] ==> out_path[i];
	}
	for(var i = 0; i < polygonSize; i++) {
		// Assign output signals
		vertx[i] ==> poly_vertx[i]; //13
		verty[i] ==> poly_verty[i];
	}
}

component main = PolygonPresentation(4, 13, 4);
