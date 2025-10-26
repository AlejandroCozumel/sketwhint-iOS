import SwiftUI

enum LegalDocumentType {
    case termsOfService
    case privacyPolicy

    func navigationTitle(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.termsOfService, .english):
            return "Terms of Service"
        case (.termsOfService, .spanish):
            return "Términos de Servicio"
        case (.privacyPolicy, .english):
            return "Privacy Policy"
        case (.privacyPolicy, .spanish):
            return "Política de Privacidad"
        }
    }

    func content(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.termsOfService, .english):
            return LegalDocuments.termsEnglish
        case (.termsOfService, .spanish):
            return LegalDocuments.termsSpanish
        case (.privacyPolicy, .english):
            return LegalDocuments.privacyEnglish
        case (.privacyPolicy, .spanish):
            return LegalDocuments.privacySpanish
        }
    }
}

struct LegalDocumentView: View {
    @StateObject private var localization = LocalizationManager.shared
    let documentType: LegalDocumentType

    var body: some View {
        ScrollView {
            Text(documentType.content(for: localization.currentLanguage))
                .bodySmall()
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .contentPadding()
        }
        .background(AppColors.backgroundLight)
        .navigationTitle(documentType.navigationTitle(for: localization.currentLanguage))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum LegalDocuments {
    static let termsEnglish = #"""
SketchWink - Terms of Service
Last updated and effective date: 26 October 2025

Please read these Terms of Service ("Agreement" or "Terms of Service") carefully before using the services offered by SketchWink ("SketchWink," "we," "us," or "our"). This Agreement sets forth the legally binding terms and conditions for your use of the SketchWink website and all related services, including, without limitation, any features, content, websites (including sketchwink.com) or applications offered from time to time by SketchWink in connection therewith (collectively "Service(s)"). By using the Services in any manner, you agree to be bound by this Agreement.

"The Site" refers to the website operated by SketchWink, including but not limited to sketchwink.com, as well as any associated applications, services, features, content, and functionalities offered by SketchWink.

Acceptance of Terms of Service
The Service is offered subject to acceptance without modification of these Terms of Service and all other operating rules, policies, and procedures that may be published from time to time in connection with the Services by SketchWink. In addition, some services offered through the Service may be subject to additional terms and conditions promulgated by SketchWink from time to time; your use of such services is subject to those additional terms and conditions, which are incorporated into these Terms of Service by this reference.

SketchWink may, in its sole discretion, refuse to offer the Service to any person or entity and change its eligibility criteria at any time. This provision is void where prohibited by law, and the right to access the Service is revoked in such jurisdictions.

Rules and Conduct
By using SketchWink, you agree that the Service is intended solely for the purpose of creating AI models of yourself or other individuals for whom you have obtained explicit written consent. You acknowledge and agree that when creating AI models of other individuals, you must have their express written consent to use their photos and to create, train, and generate AI-generated images of them.

By using SketchWink to create an AI model, you confirm that you are creating a model of yourself and are over 18 years old (or the legal age in your country) and are not a politically exposed person, or you have obtained explicit written consent from any individual whose likeness you are using and confirm they are over 18 years old (or the legal age in their respective country, whichever is higher) and they are not a politically exposed person.

By using the SketchWink app, you agree that you are at least 18 years old or have reached the legal age of majority in your country of residence. If you are under 18 or the legal age in your country (whichever is higher), you are prohibited from using this app. It is your responsibility to ensure that you comply with your local laws regarding age restrictions for digital services.

SketchWink's video creation functionality is strictly for lawful and ethical purposes. By using the app, you agree not to create or distribute videos that: 1) impersonate real individuals without their explicit consent, 2) engage in or promote scams, fraud, or other misleading activities, 3) promote or sell illegal products, services, or content, 4) engage in political campaigning, advocacy, or misinformation, 5) produce deepfake content with the intent to deceive, defraud, or mislead others, 6) create content that violates privacy or portrays individuals in a harmful or false light, 7) distribute violent, hateful, or discriminatory content of any kind, 8) create false photography or documents to breach people's accounts. You agree to only use the video creation functionality for positive and lawful purposes, such as but not limited to: 1) creating advertisements for legitimate products and services, 2) marketing campaigns that promote legal and ethical businesses, 3) explainer videos or tutorials to educate viewers, 4) educational content for personal or commercial use, 5) any other purpose that complies with applicable laws and this TOS.

As a condition of use, you promise not to use the Service for any purpose that is prohibited by the Terms of Service. By way of example, and not as a limitation, you shall not (and shall not permit any third party to) take any action (including making use of the Site, any assets, or our models or derivatives of our models) that would constitute a violation of any applicable law, rule or regulation; infringes upon any intellectual property or other right of any other person or entity; is threatening, abusive, harassing, defamatory, libelous, deceptive, fraudulent, invasive of another's privacy, tortious, obscene, offensive, furthering of self-harm or profane; creates assets that exploit or abuse children; generates or disseminates verifiably false information with the purpose of harming others; impersonates or attempts to impersonate others; generates or disseminates personally identifying or identifiable information; creates assets that imply or promote support of a terrorist organization; creates assets that condone or promote violence against people based on any protected legal category.

You agree to not use the Service for the purpose of generating nudes or pornography.

By using the Service and uploading any content, you expressly acknowledge and agree that you will not upload, post, generate or share any photographs or content depicting minors (individuals under the age of 18). You further agree that, in compliance with applicable laws and regulations, we reserve the right to monitor and review any uploaded or generated content, and if we identify any content featuring minors, we will immediately remove such content and report any instances of potential child exploitation, endangerment, or abuse to the appropriate law enforcement authorities in your respective jurisdiction. By using our platform, you consent to such monitoring, review, and reporting, and you understand that you may be subject to legal repercussions if you violate these terms.

Further, you shall not (directly or indirectly): (i) take any action that imposes or may impose an unreasonable or disproportionately large load on SketchWink's (or its third party providers') infrastructure; (ii) interfere or attempt to interfere with the proper working of the Service or any activities conducted on the Service; (iii) bypass any measures SketchWink may use to prevent or restrict access to the Service (or parts thereof); (iv) use any method to extract data from the Services, including web scraping, web harvesting, or web data extraction methods, other than as permitted through an allowable API; (v) reverse assemble, reverse compile, decompile, translate or otherwise attempt to discover the source code or underlying components of models, algorithms, and systems of the Services that are not open (except to the extent such restrictions are contrary to applicable law); and (vi) reproduce, duplicate, copy, sell, resell or exploit any portion of the Site, use of the Site, or access to the Site or any contact on the Site, without our express written permission.

DMCA and Takedowns Policy
SketchWink utilizes artificial intelligence systems to produce the assets. Such assets may be unintentionally similar to copyright protected material or trademarks held by others. We respect rights holders internationally and we ask our users to do the same.

Modification of Terms of Service
At its sole discretion, SketchWink may modify or replace any of the Terms of Service, or change, suspend, or discontinue the Service (including without limitation, the availability of any feature, database, or content) at any time by posting a notice on the SketchWink website or Service or by sending you an email. SketchWink may also impose limits on certain features and services or restrict your access to parts or all of the Service without notice or liability. It is your responsibility to check the Terms of Service periodically for changes. Your continued use of the Service following the posting of any changes to the Terms of Service constitutes acceptance of those changes.

Trademarks and Patents
All SketchWink logos, marks and designations are trademarks or registered trademarks of SketchWink. All other trademarks mentioned on this website are the property of their respective owners. The trademarks and logos displayed on this website may not be used without the prior written consent of SketchWink or their respective owners. Portions, features and/or functionality of SketchWink's products may be protected under SketchWink patent applications or patents.

Licensing Terms
Subject to your compliance with this Agreement, the conditions herein and any limitations applicable to SketchWink or by law: (i) you are granted a non-exclusive, limited, non-transferable, non-sublicensable, non-assignable, freely revocable license to access and use the Service for business or personal use; (ii) you own all assets you create with the Services; and (iii) we hereby assign to you all rights, title and interest in and to such assets for your personal or commercial use. Otherwise, SketchWink reserves all rights not expressly granted under these Terms of Service. Each person must have a unique account and you are responsible for any activity conducted on your account. A breach or violation of any of our Terms of Service may result in an immediate termination of your right to use our Service.

By using the Services, you grant to SketchWink, its successors, and assigns a perpetual, worldwide, non-exclusive, sublicensable, no-charge, royalty-free, irrevocable copyright license to use, copy, reproduce, process, adapt, modify, publish, transmit, prepare derivative works of, publicly display, publicly perform, sublicense, and/or distribute text prompts and images you input into the Services, or assets produced by the Service at your direction. This license authorizes SketchWink to make the assets available generally and to use such assets as needed to provide, maintain, promote and improve the Services, as well as to comply with applicable law and enforce our policies. You agree that this license is provided with no compensation paid to you by SketchWink for your submission or creation of assets, as the use of the Services by you is hereby agreed as being sufficient compensation for the grant of rights herein. You also grant each other user of the Service a worldwide, non-exclusive, royalty-free license to access your publicly available assets through the Service, and to use those assets (including to reproduce, distribute, modify, display, and perform them) only as enabled by a feature of the Service. The license to SketchWink survives termination of this Agreement by any party, for any reason.

Fees and Payments
You agree that SketchWink provides you immediate access to digital content and begins service consumption immediately upon purchase, without the standard 14-day withdrawal period. Therefore, you expressly waive your right to withdraw from this purchase. Due to the high costs of GPU processing, we are not able to offer refunds because we reserve servers and incur high costs for your usage immediately. The subscription will be automatically renewed for the same period of time after the agreed term. If you do not wish to renew your subscription at the end of the term, you should cancel prior to the renewal date of your subscription.

SketchWink offers a paid Service. You can sign up for a monthly or yearly subscription that will automatically renew on a monthly or yearly basis. You can stop using the Service and cancel your subscription at any time through the website (click Billing). If you cancel your subscription, you will not receive a refund or credit for any amounts that have already been billed or paid. SketchWink reserves the right to change its prices and offering (like credits or models) at any time. If you are on a subscription plan, changes to pricing will not apply until your next renewal.

Unless otherwise stated, your subscription fees ("Fees") do not include federal, state, local, and foreign taxes, duties, and other similar assessments ("Taxes"). You are responsible for all Taxes associated with your purchase and we may invoice you for such Taxes. You agree to timely pay such Taxes and provide us with documentation showing the payment or additional evidence that we may reasonably require. If any amount of your Fees are past due, we may suspend your access to the Services after we provide you written notice of late payment. You may not create more than one account to benefit from the free tier of our Services. If we believe you are not using the free tier in good faith, we may charge you standard fees or stop providing access to the Services.

Termination
SketchWink may terminate your access to all or any part of the Service at any time if you fail to comply with these Terms of Service, which may result in the forfeiture and destruction of all information associated with your account. Further, either party may terminate the Services for any reason and at any time upon written notice. If you wish to terminate your account, you may do so by following the instructions on the Service. Any fees paid hereunder are non-refundable. Upon any termination, all rights and licenses granted to you in this Agreement shall immediately terminate, but all provisions hereof which by their nature should survive termination shall survive termination, including, without limitation, warranty disclaimers, indemnity, and limitations of liability.

Indemnification
You shall defend, indemnify, and hold harmless SketchWink, its affiliates and each of its, and its affiliates' employees, contractors, directors, suppliers, and representatives from all liabilities, losses, claims, and expenses, including reasonable attorneys' fees, that arise from or relate to (i) your use or misuse of, or access to, the Service, or (ii) your violation of the Terms of Service or any applicable law, contract, policy, regulation, or other obligation. SketchWink reserves the right to assume the exclusive defense and control of any matter otherwise subject to indemnification by you, in which event you will assist and cooperate with SketchWink in connection therewith.

Limitation of Liability
In no event shall SketchWink or its directors, employees, agents, partners, suppliers or content providers, be liable under contract, tort, strict liability, negligence or any other legal or equitable theory with respect to the Service (i) for any lost profits, data loss, cost of procurement of substitute goods or services, or special, indirect, incidental, punitive, or consequential damages of any kind whatsoever, or substitute goods or services, (ii) for your reliance on the Service or (iii) for any direct damages in excess (in the aggregate) of the fees paid by you for the Service or, if greater, $500 USD. Some jurisdictions do not allow the exclusion or limitation of incidental or consequential damages, so the above limitations and exclusions may not apply to you.

In no event shall SketchWink or its owners be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with use of this application.

Disclaimer
All use of the Service and any content is undertaken entirely at your own risk. The Service (including, without limitation, the SketchWink web app and any content) is provided "as is" and "as available" and is without warranty of any kind, express or implied, including, but not limited to, the implied warranties of title, non-infringement, merchantability and fitness for a particular purpose, and any warranties implied by any course of performance or usage of trade, all of which are expressly disclaimed. Some jurisdictions do not allow limitations on how long an implied warranty lasts, so the above limitations may not apply to you.

Age Requirements
By accessing the Services, you confirm that you are at least 18 years old and meet the minimum age of digital consent in your country. If you are not old enough to consent to our Terms of Service in your country, your parent or guardian must agree to this Agreement on your behalf. Please ask your parent or guardian to read these terms with you. If you are a parent or legal guardian, and you allow your teenager to use the Services, then these terms also apply to you and you are responsible for your teenager's activity on the Services. No assurances are made as to the suitability of the assets for you.

Miscellaneous
The Terms of Service are the entire agreement between you and SketchWink with respect to the Service, and supersede all prior or contemporaneous communications and proposals (whether oral, written, or electronic) between you and SketchWink with respect to the Service. If any provision of the Terms of Service is found to be unenforceable or invalid, that provision will be limited or eliminated to the minimum extent necessary so that the Terms of Service will otherwise remain in full force and effect and enforceable. The failure of either party to exercise in any respect any right provided for herein shall not be deemed a waiver of any further rights hereunder. SketchWink shall not be liable for any failure to perform its obligations hereunder due to any cause beyond SketchWink's reasonable control. The Terms of Service are personal to you, and are not assignable or transferable by you except with SketchWink's prior written consent. SketchWink may assign, transfer, or delegate any of its rights and obligations hereunder without consent. No agency, partnership, joint venture, or employment relationship is created as a result of the Terms of Service and neither party has any authority of any kind to bind the other in any respect. Except as otherwise provided herein, all notices under the Terms of Service will be in writing and will be deemed to have been duly given when received, if personally delivered or sent by certified or registered mail, return receipt requested; when receipt is electronically confirmed, if transmitted by email; or two days after it is sent, if sent for next day delivery by recognized overnight delivery service.

Your Rights to Use the Site; Our Content and Intellectual Property Rights
Subject to these Terms, SketchWink grants you a limited, non-exclusive, revocable, and personal license to access and use the Site solely for noncommercial and informational purposes.

Unless otherwise expressly indicated by SketchWink, all content displayed or made available on the Site, including without limitation, text, images, illustrations, designs, logos, domain names, service marks, software, scripts, and the selection, compilation and arrangement of any of the foregoing is owned by SketchWink, its affiliates, licensors and/or other third parties ("Site Content"). The Site and all Site Content are protected by copyright, trade dress, trademark, moral rights, and other intellectual property laws in Mexico, the United States, and other international jurisdictions. All such rights are reserved.

All registered and unregistered trademarks, logos, and service marks are the property of SketchWink and/or their respective owners. Nothing displayed or accessed in connection with the Site shall be construed as granting by implication, estoppel, or otherwise, any license or right to use any trademark, logo, or service mark displayed in connection with the Site without the owner's prior written permission, except as otherwise described herein.

Prohibited Uses
You are fully responsible for your activities while using the Site, including any content, information or other materials you post or upload to the Site, and you bear all risks associated with the use of the Site. By agreeing to these Terms, you agree to comply with all applicable federal, state, and local laws and regulations in connection with your use of the Site. You also agree not to use the Site to engage in any prohibited conduct or to assist any other person or entity in engaging in any prohibited conduct.

We reserve the right (but not the obligation) in our sole discretion to (1) monitor the Site for violations of these Terms; (2) take appropriate legal action against anyone who uses or accesses the Site in a manner that we believe violates the law or these Terms, including without limitation, reporting such user to law enforcement authorities; (3) deny access to the Site or any features of the Site to anyone who violates these Terms or who we believe interferes with the ability of others to enjoy our Site or infringes the rights of others; and (4) otherwise manage the Site in a manner designed to protect our rights and property and to facilitate the proper functioning of the Site.

You are prohibited from using the Site for the commission of harmful or illegal activities. Accordingly, you may not, or assist any other person to:
- Violate these Terms or other policies and terms posted on, or otherwise applicable to, the Site;
- Include sensitive personal information (such as phone numbers, residential addresses, health information, social security numbers, driver's license numbers, or other account numbers) about yourself or any other person in any webform on the Site;
- Copy or adapt the Site's software, including but not limited to Flash, PHP, HTML, JavaScript, or other code;
- Upload any material, program, or software that contains any virus, worm, spyware, Trojan horse or other program or code designed to interrupt, destroy or limit the functionality of the Site, launch a denial of service attack, or in any other way attempt to interfere with the functioning and availability of the Site;
- Except as may be the result of standard search engine or Internet browser usage, use, launch, develop, or distribute any automated system, including, without limitation, any spider, robot, cheat utility, scraper, offline reader, or any data mining or similar data gathering extraction tools to access the Site, or use or launch any unauthorized script or other software;
- Interfere with, disable, vandalize or disrupt the Site or servers or networks connected to the Site;
- Hack into, penetrate, disable, or otherwise circumvent the security measures of the Site or servers or networks connected to the Site;
- Impersonate another person or falsely represent an affiliation with any organization or institution;
- Send email to the addresses linked or made available on the Site (including in these Terms) to harass, annoy, intimidate, or threaten any of our employees or agents;
- Use the Site in any way that violates any applicable national, federal, state, local or international law or regulation; or
- Attempt to do any of the above.

DMCA Copyright Infringement Notice
We have implemented the procedures described in the Digital Millennium Copyright Act of 1998 ("DMCA"), 17 U.S.C. § 512, regarding the reporting of alleged copyright infringement and the removal of or disabling access to the infringing material. If you have a good faith belief that copyrighted material on the Site is being used in a way that infringes the copyright over which you are authorized to act, you may make a Notice of Infringing Material.

Before serving a Notice of Infringing Material, you may wish to contact a lawyer to better understand your rights and obligations under the DMCA and other applicable laws. For example, if your Notice fails to comply with all requirements of sections 512(c)(3), your Notice may not be effective.

DMCA Agent Contact Information:
SketchWink
Attn: DMCA Agent
Calle 12 Norte Esq. 70 Av #599
Cozumel, Quintana Roo, Mexico
Email: alejandro@sketchwink.com

Termination of Repeat Infringers
We will terminate or disable your use of the Site in appropriate circumstances if you are deemed by us to be a repeat copyright infringer.

Disclaimer (Site)
The Site is provided on an "as is" and "as available" basis. Except to the extent prohibited by law, we make no warranties (express, implied, statutory, or otherwise) with respect to the Site or the content of any websites linked to the Site and disclaim all warranties, including, but not limited to, warranties of merchantability, fitness for a particular purpose, title, and non-infringement. SketchWink makes no warranty that (a) the Site will meet your requirements, (b) access to and use of the Site will be uninterrupted, timely, secure, or error-free, and (c) the results that may be obtained from the use of the Site will be accurate or reliable.

SketchWink reserves the right in our sole discretion to modify or discontinue, temporarily or permanently, the Site (or any part thereof) with or without notice. You agree that SketchWink will not be liable to you or to any third party for any modification or discontinuance of the Site, except as set forth in the "Limitation of Liability" section above.

Limitation of Liability (Site)
You expressly understand and agree that neither SketchWink nor its officers, employees, directors, shareholders, licensors, service providers, and agents will be liable for any indirect, incidental, special, consequential, punitive, exemplary damages, or damages for loss of profits including but not limited to, damages for loss of goodwill, use, data or other intangible losses (even if SketchWink has been advised of the possibility of such damages), whether based on contract, tort, negligence, strict liability or otherwise, resulting from: (a) the use or the inability to use the Site or any related information; (b) conduct of any third party (including other users) of the Site; or (c) any other matter relating to the Site. In no event will SketchWink's total liability to you for all damages, losses or causes of action exceed one hundred dollars ($100). If you are merely dissatisfied with any portion of the Site or with these Terms, your sole and exclusive remedy is to discontinue the use of the Site.

You agree that regardless of any statute or law to the contrary, any claim or cause of action that you may have arising out of or related to the use of the Site or these Terms must be filed by you within one (1) year after such claim or cause of action arose or be forever barred.

Links to and From Other Websites
You may gain access to other websites via links on the Site. These Terms apply to the Site only and do not apply to other parties' websites. Similarly, you may have come to the Site via a link from another website. The terms of service of other websites do not apply to the Site. SketchWink assumes no responsibility for any terms of service or material outside of the Site accessed via any link. You are free to establish a hypertext link to the Site so long as the link does not state or imply any sponsorship of your website or service by SketchWink or the Site. Unless expressly agreed to by us in writing, reference to any of our products, services, processes or other information by trade name, trademark, logo, or otherwise by you or any third party does not constitute or imply endorsement, sponsorship or recommendation thereof by us. You may not, without our prior written permission, frame or inline link any of the content of the Site, scrape the Site or incorporate into another website or other service any of our material, content or intellectual property unless you are otherwise permitted by us to do so in accordance with a license or subject to separate terms.

Dispute Resolution by Binding Arbitration
Please read this section carefully, as it affects your rights.

Agreement to Arbitrate.
This Dispute Resolution by Binding Arbitration section is referred to in these Terms as the "Arbitration Agreement." You and SketchWink agree that any and all disputes, claims, demands, or causes of action ("Claims") that have arisen or may arise between you and us, whether arising out of or relating to these Terms, the Site, or any aspect of the relationship or transactions between us, will be resolved exclusively through final and binding arbitration before a neutral arbitrator, rather than in a court by a judge or jury, in accordance with the terms of this Arbitration Agreement, except that you or we may (but are not required to) assert individual Claims in small claims court if such Claims are within the scope of such court's jurisdiction. Further, this Arbitration Agreement does not preclude you from bringing issues to the attention of federal, state, or local agencies, and such agencies can, if the law allows, seek relief against us on your behalf. You agree that, by entering into these Terms, you and we are each waiving the right to a trial by jury or to participate in a class action and that our respective rights will be determined by a neutral arbitrator, not a judge or jury. The Mexican Arbitration Law governs the interpretation and enforcement of this Arbitration Agreement.

You agree that any claim or cause of action arising out of or related to these Terms, the Site, or any services provided must be filed within one (1) year after the event or facts giving rise to the claim or cause of action occurred. To the extent permitted by applicable law, any claims or causes of action not filed within this period are permanently barred.

Prohibition of Class and Representative Actions and Non-Individualised Relief.
You and we agree that each of us may bring Claims against the other only on an individual basis and not as a plaintiff or class member in any purported class or representative action or proceeding.

Pre-Arbitration Dispute Resolution.
Except as otherwise provided herein, all issues are for the arbitrator to decide, including, but not limited to, threshold issues relating to the scope, enforceability, and arbitrability of this Arbitration Agreement and issues relating to (a) whether the terms of these Terms (or any aspect thereof) are enforceable, unconscionable, or illusory and (b) any defence to arbitration, including waiver, delay, laches, or estoppel. During arbitration proceedings, the amount of any settlement offer made by SketchWink or you shall not be disclosed to the arbitrator. Although arbitration proceedings are usually simpler and more streamlined than trials and other judicial proceedings, the arbitrator can award the same damages and relief on an individual basis that a court can award to an individual under these Terms and applicable law. While an arbitrator may award declaratory or injunctive relief, the arbitrator may do so only with respect to the individual party seeking relief and only to the extent necessary to provide relief warranted by the individual party's Claim. The arbitrator's decision and judgment thereon will not have a precedent or collateral estoppel effect on any other Claim. Decisions by the arbitrator are enforceable in court and may be overturned by a court only for very limited reasons. Any arbitration hearings will take place in Cozumel, Quintana Roo, Mexico, at another mutually agreeable location or, if both parties agree, by telephone or video conference. Whether the arbitration will be conducted solely on the basis of documents submitted to the arbitrator or by a hearing will be determined in accordance with applicable arbitration rules. Regardless of the manner in which the arbitration is conducted, the arbitrator will issue a reasoned written decision sufficient to explain the essential findings and conclusions on which the award is based.

Small Claims Court.
Subject to applicable jurisdictional requirements, either party may elect to pursue a Claim in a local small claims court rather than through arbitration so long as the matter remains in a small claims court and proceeds only on an individual basis.

Cost of Arbitration.
Payment of all filing, administration and arbitrator fees (collectively, the "Arbitration Fees") will be governed by the applicable arbitration rules unless otherwise provided in this Arbitration Agreement. If you are able to demonstrate to the arbitrator's satisfaction that you are economically unable to pay your portion of the Arbitration Fees or if the arbitrator otherwise determines for any reason that you should not be required to pay your portion of the Arbitration Fees, we will pay your portion of such fees, subject to allocation in the arbitrator's award. In addition, if you demonstrate to the arbitrator that the costs of arbitration will be prohibitive as compared to the costs of litigation, we will pay as much of the Arbitration Fees as the arbitrator deems necessary to prevent the arbitration from being cost-prohibitive. Any payment of attorneys' fees will be governed by the applicable arbitration rules.

Confidentiality.
Each of the parties shall maintain the strictly confidential nature of the arbitration, including all aspects of the arbitration proceeding and any ruling, decision, or award by the arbitrator, and shall not (without the prior written consent of the other party) disclose to any third party the fact, existence, content, award, or other results of the arbitration, except as may be necessary to enforce, enter, or challenge such award in a court of competent jurisdiction or as otherwise required by law.

Opt Out.
You may reject this Arbitration Agreement, in which case only a court may be used to resolve any Claim. To reject this provision, you must send us an opt-out notice (the "Opt Out") within thirty (30) days after you first access the Site. The Opt-Out must be sent to the SketchWink Notice Address below. The Opt-Out must include your name, phone number and the email address you used to sign up and use the Site. This is the only way of opting out of this Arbitration Agreement. Opting out will not affect any other aspect of these Terms and will have no effect on any other or future agreements you may reach to arbitrate with us.

Severability.
If a court or the arbitrator decides that any term or provision of this Arbitration Agreement (other than the paragraph above titled "Prohibition of Class and Representative Actions and Non-Individualised Relief") is invalid or unenforceable, the parties agree to replace such term or provision with a term or provision that is valid and enforceable, and that comes closest to expressing the intention of the invalid or unenforceable term or provision, and this Arbitration Agreement will be enforceable as so modified. If a court or the arbitrator decides that any of the provisions of the paragraph titled "Prohibition of Class and Representative Actions and Non-Individualised Relief" are invalid or unenforceable, then the entirety of this Arbitration Agreement will be null and void, unless such provisions are deemed to be invalid or unenforceable solely with respect to Claims for public injunctive relief. The remainder of these Terms will continue to apply.

Choice of Law
Any and all Claims shall be governed by the federal laws of Mexico and the laws of the State of Quintana Roo in all respects, without regard for the jurisdiction or forum in which the user is domiciled, resides or located at the time of such access or use. Except as provided in the Arbitration Agreement, all Claims will be brought in the federal or state courts located in Quintana Roo, Mexico, and you and SketchWink each unconditionally, voluntarily, and irrevocably consent to the exclusive personal jurisdiction and venue of those courts.

You hereby irrevocably and unconditionally waive any right you may have to a trial by jury in respect of any action or proceeding arising out of or relating to these Terms that is not subject to arbitration, as set forth above.

A printed version of these Terms and any other notice given in electronic form will be admissible in any arbitral, judicial, or administrative proceedings based upon or relating to these Terms and your use of the Site to the same extent and subject to the same conditions as other business documents and records originally generated and maintained in printed form.

Waiver and Severability
If you do not comply with a portion of these Terms and we do not take action right away, this does not mean we are giving up any of our rights under these Terms. If any part of these Terms is determined to be invalid or unenforceable by a court of competent jurisdiction or arbitrator, the remainder of the Terms shall be enforced to the maximum extent permitted by law.

Entire Agreement; Construction
These Terms contain the entire agreement between you and SketchWink regarding your use of the Site and supersede any prior or contemporaneous agreements, communications, or understandings between you and SketchWink on that subject.

Assignment and Delegation
You may not assign or delegate these Terms or any rights or obligations under these Terms. Any attempted or purported assignment or delegation shall be null and void and will automatically terminate your right to use the Site. We may assign or delegate these Terms or any rights or obligations under these Terms in connection with a merger, acquisition or sale of all or substantially all of our assets or to any affiliate or as part of a corporate reorganisation.

Changes to these Terms
We may change or modify these Terms by posting a revised version on the Site or by otherwise providing notice to you, and we will state at the top of the revised Terms the date they were last revised. Changes will not apply retroactively and will become effective no earlier than fourteen (14) calendar days after they are posted, except for changes addressing issues made for legal reasons, which will be effective immediately. Your continued use of the Site after any change means you agree to the new Terms.

Contact Us
SketchWink
Calle 12 Norte Esq. 70 Av #599
Cozumel, Quintana Roo, Mexico
Email: alejandro@sketchwink.com
"""#
    static let termsSpanish = #"""
SketchWink - Términos de Servicio
Última actualización y fecha de entrada en vigor: 26 de octubre de 2025

Por favor lee estos Términos de Servicio ("Acuerdo" o "Términos de Servicio") con detenimiento antes de usar los servicios que ofrece SketchWink ("SketchWink", "nosotros" o "nuestro"). Este Acuerdo establece los términos y condiciones que rigen legalmente tu uso del sitio web de SketchWink y de todos los servicios relacionados, incluyendo, sin limitación, cualquier funcionalidad, contenido, sitios web (incluido sketchwink.com) o aplicaciones que SketchWink ofrezca de tiempo en tiempo en relación con ello (colectivamente, los "Servicio(s)"). Al usar los Servicios de cualquier manera, aceptas estar obligado por este Acuerdo.

"El Sitio" se refiere al sitio web operado por SketchWink, incluido pero no limitado a sketchwink.com, así como a todas las aplicaciones, servicios, funcionalidades, contenido y características asociadas que ofrece SketchWink.

Aceptación de los Términos de Servicio
El Servicio se ofrece supeditado a la aceptación sin modificaciones de estos Términos de Servicio y de todas las demás normas operativas, políticas y procedimientos que SketchWink pueda publicar de tiempo en tiempo en relación con los Servicios. Además, algunos servicios ofrecidos a través del Servicio pueden estar sujetos a términos y condiciones adicionales que SketchWink emita ocasionalmente; tu uso de dichos servicios está sujeto a esos términos y condiciones adicionales, que se incorporan a estos Términos de Servicio por referencia.

SketchWink puede, a su entera discreción, negarse a ofrecer el Servicio a cualquier persona o entidad y cambiar sus criterios de elegibilidad en cualquier momento. Esta disposición es nula donde la ley lo prohíba y, en esas jurisdicciones, se revoca el derecho a acceder al Servicio.

Reglas y Conducta
Al utilizar SketchWink, aceptas que el Servicio tiene por finalidad exclusiva la creación de modelos de IA de ti mismo o de otras personas para las que hayas obtenido su consentimiento expreso por escrito. Reconoces y aceptas que, al crear modelos de IA de otras personas, debes contar con su consentimiento expreso por escrito para usar sus fotografías y para crear, entrenar y generar imágenes generadas por IA de ellas.

Al usar SketchWink para crear un modelo de IA, confirmas que estás creando un modelo de ti mismo y que tienes más de 18 años (o la mayoría de edad en tu país) y que no eres una persona políticamente expuesta, o bien que has obtenido el consentimiento expreso por escrito de cualquier persona cuya imagen estés usando y confirmas que es mayor de 18 años (o la edad legal en su país, la que sea mayor) y que no es una persona políticamente expuesta.

Al usar la aplicación de SketchWink, aceptas que tienes al menos 18 años o has alcanzado la mayoría de edad en tu país de residencia. Si eres menor de 18 años o de la edad legal en tu país (la que sea mayor), tienes prohibido usar esta aplicación. Es tu responsabilidad asegurarte de que cumples con las leyes locales sobre restricciones de edad para servicios digitales.

La funcionalidad de creación de video de SketchWink es estrictamente para fines legales y éticos. Al usar la aplicación, aceptas no crear ni distribuir videos que: 1) suplanten a personas reales sin su consentimiento expreso, 2) participen o promuevan estafas, fraudes u otras actividades engañosas, 3) promuevan o vendan productos, servicios o contenido ilegales, 4) participen en campañas políticas, defensa o desinformación, 5) produzcan contenido deepfake con la intención de engañar, defraudar o inducir a error, 6) creen contenido que viole la privacidad o retrate a las personas de manera dañina o falsa, 7) distribuyan contenido violento, odioso o discriminatorio de cualquier clase, 8) creen fotografías o documentos falsos para vulnerar cuentas de terceros. Aceptas usar la funcionalidad de creación de video únicamente para fines positivos y legales, como, entre otros: 1) crear anuncios de productos y servicios legítimos, 2) campañas de marketing que promuevan negocios legales y éticos, 3) videos explicativos o tutoriales para educar a la audiencia, 4) contenido educativo para uso personal o comercial, 5) cualquier otro propósito que cumpla con las leyes aplicables y con estos Términos.

Como condición de uso, te comprometes a no usar el Servicio para ningún fin prohibido por los Términos de Servicio. A modo de ejemplo, y sin limitarse a ello, no deberás (ni permitirás que un tercero) realice ninguna acción (incluido el uso del Sitio, de cualquier recurso o de nuestros modelos o derivados de nuestros modelos) que constituya una violación de cualquier ley, norma o regulación aplicable; infrinja cualquier derecho de propiedad intelectual u otro derecho de cualquier otra persona o entidad; sea amenazante, abusiva, acosadora, difamatoria, calumniosa, engañosa, fraudulenta, invasiva de la privacidad ajena, ilícita, obscena, ofensiva, fomente autolesiones o profana; cree recursos que exploten o abusen de menores; genere o difunda información verificablemente falsa con el propósito de dañar a otros; suplante o intente suplantar a otras personas; genere o difunda información personalmente identificable; cree recursos que impliquen o promuevan el apoyo a una organización terrorista; cree recursos que justifiquen o promuevan la violencia contra personas por cualquier categoría legal protegida.

Aceptas no usar el Servicio para generar desnudos o pornografía.

Al usar el Servicio y cargar contenido, reconoces y aceptas expresamente que no subirás, publicarás, generarás ni compartirás fotografías o contenido que represente a menores de edad (personas menores de 18 años). Además, aceptas que, en cumplimiento de las leyes y regulaciones aplicables, nos reservamos el derecho de monitorear y revisar cualquier contenido cargado o generado y, si identificamos contenido que incluya menores, eliminaremos dicho contenido de inmediato e informaremos cualquier caso potencial de explotación, peligro o abuso infantil a las autoridades competentes en tu jurisdicción. Al usar nuestra plataforma, consientes dicho monitoreo, revisión y reporte, y entiendes que podrías estar sujeto a consecuencias legales si violas estos términos.

Asimismo, no deberás (directa o indirectamente): (i) tomar ninguna acción que imponga o pueda imponer una carga irrazonable o desproporcionadamente grande sobre la infraestructura de SketchWink (o la de sus proveedores externos); (ii) interferir o intentar interferir con el correcto funcionamiento del Servicio o de cualquier actividad que se lleve a cabo en el Servicio; (iii) eludir cualquier medida que SketchWink pueda usar para impedir o restringir el acceso al Servicio (o a cualquier parte del mismo); (iv) usar cualquier método para extraer datos de los Servicios, incluido web scraping, web harvesting o técnicas de extracción de datos web, salvo que esté permitido a través de una API autorizada; (v) desensamblar, recompilar, descompilar, traducir o intentar descubrir el código fuente o los componentes subyacentes de los modelos, algoritmos y sistemas de los Servicios que no sean abiertos (salvo en la medida en que tales restricciones sean contrarias a la ley aplicable); y (vi) reproducir, duplicar, copiar, vender, revender o explotar cualquier parte del Sitio, el uso del Sitio o el acceso al Sitio o cualquier contacto en el Sitio, sin nuestro consentimiento expreso por escrito.

Política de Takedowns y DMCA
SketchWink utiliza sistemas de inteligencia artificial para producir los recursos. Dichos recursos pueden ser, de manera no intencional, similares a material protegido por derechos de autor o marcas comerciales de terceros. Respetamos a los titulares de derechos a nivel internacional y pedimos a nuestros usuarios que hagan lo mismo.

Modificación de los Términos de Servicio
A su entera discreción, SketchWink puede modificar o sustituir cualquier disposición de estos Términos de Servicio, o cambiar, suspender o interrumpir el Servicio (incluida, sin limitación, la disponibilidad de cualquier funcionalidad, base de datos o contenido) en cualquier momento mediante la publicación de un aviso en el sitio web o el Servicio de SketchWink o mediante el envío de un correo electrónico. SketchWink también puede imponer límites a ciertas funciones y servicios o restringir tu acceso a partes o a la totalidad del Servicio sin previo aviso ni responsabilidad. Es tu responsabilidad revisar periódicamente los Términos de Servicio para detectar cambios. Tu uso continuado del Servicio tras la publicación de cambios implica la aceptación de dichos cambios.

Marcas y Patentes
Todos los logotipos, marcas y designaciones de SketchWink son marcas comerciales o marcas registradas de SketchWink. Todas las demás marcas mencionadas en este sitio web son propiedad de sus respectivos dueños. Las marcas y logotipos exhibidos en este sitio web no pueden utilizarse sin el consentimiento previo por escrito de SketchWink o de sus respectivos propietarios. Algunas partes, características y/o funcionalidades de los productos de SketchWink pueden estar protegidas por solicitudes de patente o patentes de SketchWink.

Términos de Licencia
Sujeto a tu cumplimiento de este Acuerdo, de las condiciones aquí descritas y de cualquier limitación aplicable a SketchWink o impuesta por la ley: (i) se te concede una licencia no exclusiva, limitada, intransferible, no sublicenciable, no asignable y revocable libremente para acceder y usar el Servicio con fines comerciales o personales; (ii) eres propietario de todos los recursos que crees con los Servicios; y (iii) te cedemos todos los derechos, títulos e intereses sobre dichos recursos para tu uso personal o comercial. En lo demás, SketchWink se reserva todos los derechos no expresamente concedidos en estos Términos de Servicio. Cada persona debe tener una cuenta única y eres responsable de cualquier actividad realizada en tu cuenta. Cualquier incumplimiento o violación de nuestros Términos de Servicio puede ocasionar la terminación inmediata de tu derecho a usar nuestro Servicio.

Al usar los Servicios, otorgas a SketchWink, sus sucesores y cesionarios, una licencia de derechos de autor perpetua, mundial, no exclusiva, sublicenciable, gratuita, libre de regalías e irrevocable para usar, copiar, reproducir, procesar, adaptar, modificar, publicar, transmitir, preparar obras derivadas, exhibir públicamente, ejecutar públicamente, sublicenciar y/o distribuir los textos, indicaciones e imágenes que ingreses en los Servicios, o los recursos producidos por el Servicio bajo tu dirección. Esta licencia autoriza a SketchWink a poner los recursos a disposición del público en general y a utilizar dichos recursos según sea necesario para proporcionar, mantener, promover y mejorar los Servicios, así como para cumplir con la legislación aplicable y hacer cumplir nuestras políticas. Aceptas que esta licencia se concede sin compensación alguna por parte de SketchWink por tu envío o creación de recursos, ya que el uso de los Servicios por tu parte se considera una compensación suficiente para la concesión de derechos aquí prevista. También otorgas a cada usuario del Servicio una licencia mundial, no exclusiva y libre de regalías para acceder a tus recursos disponibles públicamente a través del Servicio y para usar dichos recursos (incluyendo su reproducción, distribución, modificación, exhibición y ejecución) solo en la medida en que lo permita una funcionalidad del Servicio. La licencia otorgada a SketchWink subsiste tras la terminación de este Acuerdo por cualquiera de las partes y por cualquier motivo.

Honorarios y Pagos
Aceptas que SketchWink te proporciona acceso inmediato a contenido digital y comienza el consumo del servicio inmediatamente después de la compra, sin el periodo estándar de desistimiento de 14 días. Por lo tanto, renuncias expresamente a tu derecho a desistir de esta compra. Debido a los altos costos del procesamiento con GPU, no podemos ofrecer reembolsos porque reservamos servidores e incurrimos en costos elevados para tu uso inmediatamente. La suscripción se renovará automáticamente por el mismo periodo de tiempo una vez concluido el plazo acordado. Si no deseas renovar tu suscripción al final del periodo, debes cancelarla antes de la fecha de renovación.

SketchWink ofrece un Servicio de pago. Puedes suscribirte a un plan mensual o anual, que se renovará automáticamente de forma mensual o anual. Puedes dejar de usar el Servicio y cancelar tu suscripción en cualquier momento a través del sitio web (haz clic en Billing). Si cancelas tu suscripción, no recibirás un reembolso ni crédito por los montos que ya hayan sido facturados o pagados. SketchWink se reserva el derecho de cambiar sus precios y oferta (como créditos o modelos) en cualquier momento. Si estás en un plan de suscripción, los cambios de precios no se aplicarán hasta tu próxima renovación.

Salvo indicación en contrario, tus cargos de suscripción ("Honorarios") no incluyen impuestos federales, estatales, locales u otros similares ("Impuestos"). Eres responsable de todos los Impuestos asociados a tu compra y podemos facturarte dichos Impuestos. Aceptas pagar oportunamente dichos Impuestos y proporcionarnos la documentación que muestre el pago u otra evidencia razonablemente requerida. Si algún monto de tus Honorarios está vencido, podemos suspender tu acceso a los Servicios después de enviarte un aviso escrito de pago tardío. No puedes crear más de una cuenta para beneficiarte de la modalidad gratuita de nuestros Servicios. Si consideramos que no estás usando la modalidad gratuita de buena fe, podemos cobrarte las tarifas estándar o dejar de brindarte acceso a los Servicios.

Terminación
SketchWink puede rescindir tu acceso a la totalidad o parte del Servicio en cualquier momento si no cumples con estos Términos de Servicio, lo que puede resultar en la pérdida y destrucción de toda la información asociada con tu cuenta. Asimismo, cualquiera de las partes puede terminar los Servicios por cualquier motivo y en cualquier momento mediante aviso por escrito. Si deseas cerrar tu cuenta, puedes hacerlo siguiendo las instrucciones del Servicio. Los honorarios pagados no son reembolsables. Tras cualquier terminación, todos los derechos y licencias que se te conceden en este Acuerdo terminarán de manera inmediata, pero todas las disposiciones que por su naturaleza deban subsistir tras la terminación subsistirán, incluidas, entre otras, las exenciones de garantías, indemnizaciones y limitaciones de responsabilidad.

Indemnización
Defenderás, indemnizarás y eximirás de responsabilidad a SketchWink, sus afiliadas y a cada uno de sus empleados, contratistas, directores, proveedores y representantes frente a toda responsabilidad, pérdida, reclamación y gasto, incluidos los honorios razonables de abogados, que surjan de o se relacionen con (i) tu uso o uso indebido del Servicio, o (ii) tu violación de los Términos de Servicio o de cualquier ley, contrato, política, regulación u otra obligación aplicable. SketchWink se reserva el derecho de asumir la defensa y control exclusivos de cualquier asunto sujeto a indemnización por tu parte, en cuyo caso colaborarás y asistirás a SketchWink.

Limitación de Responsabilidad
En ningún caso SketchWink ni sus directores, empleados, agentes, socios, proveedores o proveedores de contenido serán responsables, bajo contrato, agravio, responsabilidad objetiva, negligencia o cualquier otra teoría legal o equitativa en relación con el Servicio (i) por pérdida de beneficios, pérdida de datos, costo de obtención de bienes o servicios sustitutos, o daños especiales, indirectos, incidentales, punitivos o consecuenciales de cualquier tipo, (ii) por tu confianza en el Servicio o (iii) por daños directos que en su totalidad excedan (en el agregado) los honorarios que hayas pagado por el Servicio o, si fuera mayor, 500 USD. Algunas jurisdicciones no permiten la exclusión o limitación de daños incidentales o consecuenciales, por lo que las limitaciones y exclusiones anteriores pueden no aplicarse a ti.

En ningún caso SketchWink ni sus propietarios serán responsables por cualquier reclamación, daño u otra responsabilidad, ya sea en una acción contractual, extracontractual o de otro tipo, que surja de o esté relacionada con el uso de esta aplicación.

Descargo de Responsabilidad
Todo uso del Servicio y de cualquier contenido se realiza bajo tu propio riesgo. El Servicio (incluida, sin limitación, la aplicación web de SketchWink y cualquier contenido) se proporciona "tal cual" y "según disponibilidad" sin garantía de ningún tipo, expresa o implícita, incluyendo, entre otras, las garantías implícitas de titularidad, no infracción, comerciabilidad y adecuación para un propósito particular, y cualquier garantía implícita por cualquier curso de ejecución o uso comercial, todas las cuales se excluyen expresamente. Algunas jurisdicciones no permiten limitaciones sobre la duración de una garantía implícita, por lo que las limitaciones anteriores pueden no aplicarse.

Requisitos de Edad
Al acceder a los Servicios, confirmas que tienes al menos 18 años y que cumples la edad mínima de consentimiento digital en tu país. Si no tienes la edad suficiente para aceptar nuestros Términos de Servicio en tu país, tu padre, madre o tutor debe aceptar este Acuerdo en tu nombre. Pide a tu padre, madre o tutor que lea estos términos contigo. Si eres padre, madre o tutor legal y permites que tu hijo adolescente use los Servicios, estos términos también se aplican a ti y eres responsable de la actividad de tu hijo en los Servicios. No se hacen garantías sobre la idoneidad de los recursos para ti.

Misceláneas
Los Términos de Servicio constituyen el acuerdo completo entre tú y SketchWink respecto del Servicio, y reemplazan todas las comunicaciones y propuestas previas o contemporáneas (orales, escritas o electrónicas) entre tú y SketchWink sobre el Servicio. Si alguna disposición de los Términos de Servicio se considera inaplicable o inválida, esa disposición se limitará o eliminará en la medida mínima necesaria para que los Términos de Servicio permanezcan, en lo demás, en pleno vigor y efecto y sean ejecutables. El hecho de que cualquiera de las partes no ejerza en algún aspecto cualquier derecho previsto en este documento no se considerará una renuncia a esos derechos en el futuro. SketchWink no será responsable por cualquier incumplimiento de sus obligaciones derivado de causas fuera de su control razonable. Los Términos de Servicio son personales para ti y no son asignables ni transferibles por ti salvo con el consentimiento previo por escrito de SketchWink. SketchWink puede ceder, transferir o delegar cualquiera de sus derechos y obligaciones aquí establecidos sin tu consentimiento. Este Acuerdo no crea ninguna agencia, asociación, empresa conjunta ni relación laboral y ninguna de las partes tiene autoridad para obligar a la otra en ningún aspecto. Salvo que se disponga lo contrario, todas las notificaciones bajo los Términos de Servicio deberán hacerse por escrito y se considerarán debidamente entregadas cuando se reciban, si se entregan personalmente o se envían por correo certificado o registrado con acuse de recibo; cuando se confirme electrónicamente la recepción, si se transmiten por correo electrónico; o dos días después de su envío, si se envían para entrega al día siguiente mediante un servicio reconocido de mensajería.

Tus Derechos para Usar el Sitio; Nuestro Contenido y Derechos de Propiedad Intelectual
Sujeto a estos Términos, SketchWink te otorga una licencia limitada, no exclusiva, revocable y personal para acceder y usar el Sitio únicamente con fines informativos y no comerciales.

Salvo indicación en contrario por parte de SketchWink, todo el contenido mostrado o disponible en el Sitio, incluidos, entre otros, textos, imágenes, ilustraciones, diseños, logotipos, nombres de dominio, marcas de servicio, software, scripts y la selección, compilación y disposición de cualquiera de los anteriores es propiedad de SketchWink, sus afiliadas, licenciantes y/o terceros ("Contenido del Sitio"). El Sitio y todo el Contenido del Sitio están protegidos por las leyes de derechos de autor, imagen comercial, marca, derechos morales y otras leyes de propiedad intelectual de México, los Estados Unidos y otras jurisdicciones internacionales. Todos esos derechos están reservados.

Todas las marcas comerciales, registradas o no registradas, logotipos y marcas de servicio son propiedad de SketchWink y/o de sus respectivos propietarios. Nada de lo mostrado o accesible en relación con el Sitio se interpretará como una concesión por implicación, impedimento u otro medio, de una licencia o derecho de usar cualquier marca, logotipo o marca de servicio mostrada en relación con el Sitio sin el permiso previo por escrito del propietario, salvo que se describa lo contrario en este documento.

Usos Prohibidos
Eres plenamente responsable de tus actividades mientras usas el Sitio, incluidos el contenido, la información y otros materiales que publiques o cargues, y asumes todos los riesgos asociados con el uso del Sitio. Al aceptar estos Términos, te comprometes a cumplir todas las leyes y regulaciones federales, estatales y locales aplicables en relación con tu uso del Sitio. También aceptas no usar el Sitio para participar en conductas prohibidas ni ayudar a otra persona o entidad a hacerlo.

Nos reservamos el derecho (pero no la obligación) a nuestra entera discreción para (1) monitorear el Sitio en busca de violaciones a estos Términos; (2) tomar las acciones legales apropiadas contra cualquier persona que use o acceda al Sitio de una manera que consideremos que viola la ley o estos Términos, lo que incluye reportar a dicho usuario ante las autoridades competentes; (3) negar el acceso al Sitio o a cualquiera de sus características a quienes violen estos Términos o interfieran con la capacidad de otros para disfrutar del Sitio o infrinjan derechos de terceros; y (4) gestionar el Sitio de la manera que consideremos adecuada para proteger nuestros derechos y propiedad y facilitar su correcto funcionamiento.

Está prohibido usar el Sitio para realizar actividades dañinas o ilegales. En consecuencia, no puedes, ni ayudar a ninguna otra persona a:
- Violar estos Términos u otras políticas y términos publicados en el Sitio o aplicables al mismo;
- Incluir información personal sensible (como números telefónicos, direcciones residenciales, información de salud, números de seguridad social, números de licencias de conducir u otros números de cuenta) sobre ti o cualquier otra persona en cualquier formulario del Sitio;
- Copiar o adaptar el software del Sitio, incluyendo pero no limitándose a Flash, PHP, HTML, JavaScript u otro código;
- Subir cualquier material, programa o software que contenga virus, gusanos, spyware, troyanos u otro programa o código diseñado para interrumpir, destruir o limitar la funcionalidad del Sitio, lanzar un ataque de denegación de servicio o interferir de cualquier otro modo con el funcionamiento y la disponibilidad del Sitio;
- Salvo en la medida en que sea resultado del uso estándar de motores de búsqueda o navegadores de Internet, usar, lanzar, desarrollar o distribuir cualquier sistema automatizado, incluyendo, entre otros, spiders, robots, utilidades de trampa, scrapers, lectores offline o cualquier herramienta de minería de datos o extracción similar para acceder al Sitio, o usar o lanzar cualquier script no autorizado u otro software;
- Interferir, deshabilitar, vandalizar o interrumpir el Sitio o los servidores o redes conectados al Sitio;
- Hackear, penetrar, deshabilitar o eludir de otro modo las medidas de seguridad del Sitio o de los servidores o redes conectados al Sitio;
- Suplantar a otra persona o representar falsamente una afiliación con cualquier organización o institución;
- Enviar correos electrónicos a las direcciones vinculadas o disponibles en el Sitio (incluidas en estos Términos) para acosar, molestar, intimidar o amenazar a cualquiera de nuestros empleados o agentes;
- Usar el Sitio de cualquier manera que viole leyes o regulaciones nacionales, federales, estatales, locales o internacionales aplicables; o
- Intentar realizar cualquiera de las acciones anteriores.

Aviso de Infracción de Derechos de Autor Conforme a la DMCA
Hemos implementado los procedimientos descritos en la Digital Millennium Copyright Act de 1998 ("DMCA"), 17 U.S.C. § 512, sobre el reporte de presuntas infracciones de derechos de autor y la eliminación o deshabilitación del acceso al material infractor. Si crees de buena fe que material protegido por derechos de autor en el Sitio se está usando de manera que infringe los derechos sobre los cuales estás autorizado a actuar, puedes enviar un Aviso de Material Infractor.

Antes de enviar un Aviso de Material Infractor, podrías considerar consultar a un abogado para comprender mejor tus derechos y obligaciones bajo la DMCA y otras leyes aplicables. Por ejemplo, si tu Aviso no cumple todos los requisitos de la sección 512(c)(3), puede no ser efectivo.

Información de Contacto del Agente DMCA:
SketchWink
Attn: Agente DMCA
Calle 12 Norte Esq. 70 Av #599
Cozumel, Quintana Roo, México
Correo electrónico: alejandro@sketchwink.com

Terminación de Infractores Reincidentes
Terminaremos o deshabilitaremos tu uso del Sitio en circunstancias apropiadas si determinamos que eres un infractor reincidente de derechos de autor.

Descargo de Responsabilidad (Sitio)
El Sitio se proporciona "tal cual" y "según disponibilidad". Salvo en la medida en que la ley lo prohíba, no realizamos garantías (expresas, implícitas, legales o de otro tipo) respecto del Sitio ni del contenido de ningún sitio web vinculado al Sitio y renunciamos a todas las garantías, incluidas pero no limitadas a las garantías de comerciabilidad, idoneidad para un propósito particular, titularidad y no infracción. SketchWink no garantiza que (a) el Sitio cumplirá tus requisitos, (b) el acceso y uso del Sitio será ininterrumpido, oportuno, seguro o libre de errores, y (c) los resultados que puedan obtenerse del uso del Sitio serán precisos o confiables.

SketchWink se reserva el derecho, a su entera discreción, de modificar o descontinuar temporal o permanentemente el Sitio (o cualquier parte del mismo) con o sin previo aviso. Aceptas que SketchWink no será responsable ante ti ni ante terceros por cualquier modificación o descontinuación del Sitio, salvo lo establecido en la sección de "Limitación de Responsabilidad" anterior.

Limitación de Responsabilidad (Sitio)
Aceptas expresamente que ni SketchWink ni sus oficiales, empleados, directores, accionistas, licenciatarios, proveedores de servicios y agentes serán responsables por daños indirectos, incidentales, especiales, consecuenciales, punitivos, ejemplares o por pérdida de beneficios, que incluyen pero no se limitan a daños por pérdida de buena voluntad, uso, datos u otras pérdidas intangibles (aunque SketchWink haya sido advertido de la posibilidad de tales daños), ya sea que se basen en contrato, agravio, negligencia, responsabilidad objetiva u otro, derivados de: (a) el uso o la imposibilidad de usar el Sitio o cualquier información relacionada; (b) la conducta de cualquier tercero (incluidos otros usuarios) del Sitio; o (c) cualquier otro asunto relacionado con el Sitio. En ningún caso la responsabilidad total de SketchWink hacia ti por todos los daños, pérdidas o causas de acción excederá los cien dólares ($100). Si estás simple y llanamente insatisfecho con alguna parte del Sitio o con estos Términos, tu único y exclusivo recurso es dejar de usar el Sitio.

Aceptas que, independientemente de cualquier estatuto o ley en contrario, cualquier reclamación o causa de acción que puedas tener que surja de o esté relacionada con el uso del Sitio o estos Términos deberá presentarse dentro del plazo de un (1) año tras los hechos que la originaron, o quedará permanentemente prescrita.

Enlaces hacia y desde Otros Sitios Web
Puedes acceder a otros sitios web mediante enlaces en el Sitio. Estos Términos se aplican únicamente al Sitio y no a sitios web de terceros. De manera similar, es posible que hayas llegado al Sitio mediante un enlace desde otro sitio web. Los términos de servicio de otros sitios no se aplican al Sitio. SketchWink no asume responsabilidad por los términos de servicio ni por el material fuera del Sitio al que se accede mediante cualquier enlace. Puedes establecer un enlace hipertextual al Sitio siempre que el enlace no indique ni implique el patrocinio de tu sitio o servicio por parte de SketchWink o del Sitio. Salvo acuerdo previo por escrito, la referencia a nuestros productos, servicios, procesos u otra información mediante nombre comercial, marca, logotipo u otro medio por ti o por un tercero no constituye ni implica respaldo, patrocinio o recomendación por parte nuestra. No puedes, sin nuestro consentimiento previo por escrito, enmarcar o enlazar en línea cualquiera del contenido del Sitio, hacer scraping del Sitio ni incorporar a otro sitio web u otro servicio cualquiera de nuestros materiales, contenidos o propiedad intelectual, salvo que te lo permitamos de acuerdo con una licencia o sujeto a términos independientes.

Resolución de Controversias mediante Arbitraje Vinculante
Por favor lee esta sección detenidamente, ya que afecta tus derechos.

Acuerdo de Arbitraje.
Esta sección de Resolución de Controversias mediante Arbitraje Vinculante se denomina el "Acuerdo de Arbitraje". Tú y SketchWink acuerdan que todas las disputas, reclamaciones, demandas o causas de acción ("Reclamaciones") que hayan surgido o puedan surgir entre tú y nosotros, ya sea derivadas o relacionadas con estos Términos, el Sitio o cualquier aspecto de la relación o transacciones entre nosotros, se resolverán exclusivamente mediante arbitraje final y vinculante ante un árbitro neutral, en lugar de en un tribunal ante un juez o jurado, de conformidad con los términos de este Acuerdo de Arbitraje, salvo que tú o nosotros podamos (pero no estemos obligados a) presentar Reclamaciones individuales en un tribunal de demandas de menor cuantía si dichas Reclamaciones se encuentran dentro de la jurisdicción de ese tribunal. Además, este Acuerdo de Arbitraje no te impide presentar cuestiones ante agencias federales, estatales o locales, y dichas agencias pueden, si la ley lo permite, buscar reparación contra nosotros en tu nombre. Aceptas que, al celebrar estos Términos, tanto tú como nosotros renunciamos al derecho a un juicio con jurado o a participar en una acción colectiva y que nuestros respectivos derechos serán determinados por un árbitro neutral, y no por un juez o jurado. La Ley de Arbitraje Comercial de México rige la interpretación y ejecución de este Acuerdo de Arbitraje.

Aceptas que cualquier reclamación o causa de acción que surja de o esté relacionada con estos Términos, el Sitio o cualquier servicio proporcionado deberá presentarse dentro del plazo de un (1) año tras el hecho o los hechos que den lugar a la reclamación o causa de acción. En la medida permitida por la ley aplicable, las reclamaciones o causas de acción no presentadas dentro de este periodo quedan permanentemente prescritas.

Prohibición de Acciones Colectivas y de Recursos No Individualizados.
Tú y nosotros aceptamos que cada uno podrá presentar Reclamaciones contra el otro solo a título individual y no como demandante ni miembro de una supuesta acción colectiva o representativa.

Resolución de Disputas Previa al Arbitraje.
Salvo disposición en contrario, todas las cuestiones serán decididas por el árbitro, incluyendo, entre otras, las cuestiones preliminares relativas al alcance, exigibilidad y arbitrabilidad de este Acuerdo de Arbitraje y cuestiones relativas a (a) si los términos de estos Términos (o cualquier aspecto de ellos) son exigibles, abusivos o ilusorios y (b) cualquier defensa contra el arbitraje, incluyendo renuncia, demora, desidia o impedimento. Durante el arbitraje, el monto de cualquier oferta de arreglo realizada por SketchWink o por ti no se divulgará al árbitro. Aunque el arbitraje suele ser más simple y ágil que los juicios y otros procedimientos judiciales, el árbitro puede conceder los mismos daños y recursos, de manera individual, que un tribunal podría conceder a una persona conforme a estos Términos y la ley aplicable. Si bien un árbitro puede otorgar medidas declaratorias o cautelares, solo podrá hacerlo respecto de la parte individual que solicite la medida y únicamente en la medida necesaria para otorgar el remedio que la Reclamación individual justifique. La decisión del árbitro y el laudo correspondiente no tendrán efecto de precedente ni de cosa juzgada respecto de ninguna otra Reclamación. Las decisiones del árbitro son exigibles judicialmente y solo pueden ser revocadas por un tribunal por motivos muy limitados. Cualquier audiencia de arbitraje se llevará a cabo en Cozumel, Quintana Roo, México, en otro lugar convenido mutuamente o, si ambas partes están de acuerdo, por teléfono o videoconferencia. Si el arbitraje se resolverá únicamente sobre la base de documentos presentados al árbitro o mediante audiencia se determinará conforme a las reglas de arbitraje aplicables. Independientemente de la forma en que se lleve a cabo el arbitraje, el árbitro emitirá una decisión escrita motivada que explique los hallazgos y conclusiones esenciales en los que basa el laudo.

Tribunal de Menor Cuantía.
Sujeto a los requisitos jurisdiccionales aplicables, cualquiera de las partes puede optar por presentar una Reclamación en un tribunal de menor cuantía local en lugar de acudir al arbitraje, siempre que el asunto se mantenga en un tribunal de menor cuantía y se tramite de forma individual.

Costos del Arbitraje.
El pago de todas las tarifas de presentación, administración y del árbitro (colectivamente, las "Tarifas de Arbitraje") se regirá por las reglas de arbitraje aplicables, salvo que este Acuerdo de Arbitraje disponga lo contrario. Si puedes demostrar al árbitro que no puedes pagar tu parte de las Tarifas de Arbitraje o si el árbitro determina por cualquier razón que no debes pagar tu parte de dichas Tarifas, nosotros pagaremos tu parte, sujeto a lo que el árbitro disponga en el laudo. Además, si demuestras al árbitro que los costos del arbitraje serían prohibitivos en comparación con los costos del litigio, pagaremos la parte de las Tarifas de Arbitraje que el árbitro considere necesaria para evitar que el arbitraje resulte prohibitivo. El pago de honorarios de abogados se regirá por las reglas de arbitraje aplicables.

Confidencialidad.
Cada una de las partes mantendrá la estricta confidencialidad del arbitraje, incluidos todos los aspectos del procedimiento arbitral y cualquier decisión o laudo del árbitro, y no (sin el consentimiento previo por escrito de la otra parte) divulgará a ningún tercero el hecho, la existencia, el contenido, el laudo u otros resultados del arbitraje, salvo cuando sea necesario para ejecutar, elevar o impugnar dicho laudo ante un tribunal competente o cuando la ley lo requiera.

Opción de Exclusión.
Puedes rechazar este Acuerdo de Arbitraje, en cuyo caso cualquier Reclamación solo podrá resolverse ante un tribunal. Para rechazar esta disposición, debes enviarnos un aviso de exclusión (el "Aviso de Exclusión") dentro de los treinta (30) días posteriores a tu primer acceso al Sitio. El Aviso de Exclusión debe enviarse a la Dirección de Notificaciones de SketchWink indicada abajo e incluir tu nombre, número telefónico y el correo electrónico con el que te registraste y usas el Sitio. Esta es la única manera de optar por no participar en este Acuerdo de Arbitraje. La exclusión no afectará cualquier otro aspecto de estos Términos ni cualquier otro acuerdo presente o futuro para arbitrar con nosotros.

Divisibilidad.
Si un tribunal o el árbitro determina que alguna disposición de este Acuerdo de Arbitraje (distinta del párrafo anterior titulado "Prohibición de Acciones Colectivas y de Recursos No Individualizados") es inválida o inexigible, las partes acuerdan sustituirla por una disposición válida y exigible que se acerque lo más posible a la intención de la disposición inválida o inexigible, y este Acuerdo de Arbitraje será exigible conforme a dicha modificación. Si un tribunal o el árbitro decide que alguna de las disposiciones del párrafo titulado "Prohibición de Acciones Colectivas y de Recursos No Individualizados" es inválida o inexigible, entonces la totalidad de este Acuerdo de Arbitraje será nula, salvo que dichas disposiciones se consideren inválidas o inexigibles únicamente respecto de Reclamaciones que busquen medidas cautelares públicas. El resto de estos Términos continuará aplicándose.

Elección de Ley
Todas las Reclamaciones se regirán por las leyes federales de México y las leyes del Estado de Quintana Roo en todos los aspectos, sin importar la jurisdicción o foro en el que el usuario esté domiciliado, resida o se ubique al momento de acceder o usar el Sitio. Salvo lo previsto en el Acuerdo de Arbitraje, todas las Reclamaciones se presentarán ante los tribunales federales o estatales ubicados en Quintana Roo, México, y tanto tú como SketchWink aceptan incondicional, voluntaria e irrevocablemente la jurisdicción y competencia exclusivas de esos tribunales.

Por el presente, renuncias irrevocable e incondicionalmente a cualquier derecho que puedas tener a un juicio con jurado en relación con cualquier acción o procedimiento que surja de o se relacione con estos Términos que no esté sujeto a arbitraje, como se establece anteriormente.

Una versión impresa de estos Términos y cualquier otro aviso entregado en forma electrónica será admisible en cualquier procedimiento arbitral, judicial o administrativo basado en o relacionado con estos Términos y tu uso del Sitio en la misma medida y sujetos a las mismas condiciones que otros documentos y registros comerciales originalmente generados y conservados en formato impreso.

Renuncia y Divisibilidad
Si no cumples con alguna parte de estos Términos y no tomamos medidas de inmediato, eso no significa que renunciemos a cualquiera de nuestros derechos bajo estos Términos. Si algún tribunal competente o árbitro determina que una parte de estos Términos es inválida o inexigible, el resto de los Términos se hará valer en la máxima medida permitida por la ley.

Acuerdo Completo; Interpretación
Estos Términos contienen el acuerdo completo entre tú y SketchWink respecto del uso del Sitio y sustituyen cualquier acuerdo, comunicación o entendimiento previo o contemporáneo entre tú y SketchWink sobre ese tema.

Cesión y Delegación
No puedes ceder ni delegar estos Términos ni ningún derecho u obligación en virtud de ellos. Cualquier intento de cesión o delegación será nulo y provocará la terminación automática de tu derecho a usar el Sitio. Podemos ceder o delegar estos Términos o cualquier derecho u obligación en virtud de ellos en relación con una fusión, adquisición o venta de todos o casi todos nuestros activos, a cualquier afiliada o como parte de una reorganización corporativa.

Cambios a estos Términos
Podemos cambiar o modificar estos Términos publicando una versión revisada en el Sitio o proporcionando otro tipo de aviso, e indicaremos en la parte superior de los Términos revisados la fecha en que se modificaron por última vez. Los cambios no se aplicarán retroactivamente y entrarán en vigor no antes de catorce (14) días naturales después de su publicación, salvo cambios efectuados por motivos legales, que serán efectivos de inmediato. Tu uso continuado del Sitio después de cualquier cambio implica que aceptas los nuevos Términos.

Contáctanos
SketchWink
Calle 12 Norte Esq. 70 Av #599
Cozumel, Quintana Roo, México
Correo electrónico: alejandro@sketchwink.com
"""#
    static let privacyEnglish = #"""
SketchWink - Privacy Policy
Last updated and effective date: 26 October 2025

Our commitment to privacy and data protection is reflected in this Privacy Policy, which describes how we collect and process "personal information" that identifies you, such as your name or email address. Any other information besides this is "non-personal information." If we store personal information with non-personal information, we will consider that combination to be personal information.

References to our "Services" at SketchWink (sketchwink.com) in this statement include our website, apps, and other products and services. This statement applies to our Services that display or reference this Privacy Policy. Third-party services that we integrate with are governed under their own privacy policies.

Information Gathering
We learn information about you when: you directly provide it to us. For example, we collect:
- Name and contact information. We collect details such as name and email address.
- Payment information. If you make a purchase, we collect credit card numbers, financial account information and other payment details.
- Content and files. We collect and retain the photos, documents or other files you send to us in connection with delivering our Services, including via email or chat.

We collect it automatically through our products and services. For instance, we collect:
- Identifiers and device information. When you visit our websites, our web servers log your Internet Protocol (IP) address and information about your device, including device identifiers, device type, operating system, browser, and other software including type, version, language, settings, and configuration.
- Geolocation data. Depending on your device and app settings, we collect geolocation data when you use our Services.
- Usage data. We log your activity on our website, including the URL of the website from which you came to our site, pages you viewed on our website, how long you spent on a page, access times, and other details about your use of and actions on our website. We also collect information about which web elements or objects you interact with on our Service, metadata about your activity on the Service, changes in your user state, and the duration of your use of our Service.

Someone else tells us information about you. Third-party sources include, for example:
- Third-party partners. Third-party applications and services, including social networks you choose to connect with or interact with through our Services.
- Service providers. Third parties that collect or provide data in connection with work they do on our behalf, for example companies that determine your device's location based on its IP address.

When we try and understand more about you based on information you have given to us. We infer new information from other data we collect, including using automated means to generate information about your likely preferences or other characteristics ("inferences"). For example, we infer your general geographic location based on your IP address.

Information Use
We use each category of personal information about you to:
- Provide you with our Services;
- Improve and develop our Services;
- Communicate with you; and
- Provide customer support.

Information Sharing
We share information about you:
- When we have asked for and received your consent to share it;
- As needed, including to third-party service providers, to process or provide Services or products to you, but only if those entities agree to provide at least the same level of privacy protection we are committed to under this Privacy Policy;
- To comply with laws or to respond to lawful requests and legal process, provided that we will notify you unless we are legally prohibited from doing so. We will only release personal information if we believe in good faith that it is legally required; and
- Only if we reasonably believe it is necessary to prevent harm to the rights, property, or safety of you or others.

In the event of a corporate restructuring or change in our organizational structure or status, we may disclose information to a successor or affiliate.

Please note that some of our Services include integrations, references, or links to services provided by third parties whose privacy practices differ from ours. If you provide personal information to any of those third parties, or allow us to share personal information with them, that data is governed by their privacy statements.

Finally, we may share non-personal information in accordance with applicable law.

Information Protection
We implement physical, business, and technical security measures to safeguard your personal information. In the event of a security breach, we will notify you so that you can take appropriate protective steps. We only keep your personal information for as long as is needed to do what we collected it for. After that, we destroy it unless required by law.

Other Information
We retain personal data for as long as necessary to provide the services and fulfill the transactions you have requested, comply with our legal obligations, resolve disputes, enforce our agreements, and other legitimate and lawful business purposes. Because these needs can vary for different data types in the context of different services, actual retention periods can vary significantly based on criteria such as user expectations or consent, the sensitivity of the data, the availability of automated controls that enable users to delete data, and our legal or contractual obligations. As part of our normal operations, your information may be stored on computers in other countries outside of your home country. By giving us information, you consent to this kind of information transfer. Irrespective of where your information resides, we will comply with applicable law and abide by our commitments herein. We do not want your personal information if you are under 13. Do not provide it to us. If your child is under 13 and you believe your child has provided us with their personal information, please contact us to have such information removed.

European Economic Area, United Kingdom, Swiss and California Users
The following rights are granted under the European General Data Protection Regulation ("GDPR") and California Consumer Privacy Act ("CCPA"). SketchWink applies these rights to all users of our products, regardless of your location:
- The right to know what personal information is collected.
- The right to know if personal information is being shared, and to whom.
- The right to access your personal information.
- The right to exercise your privacy rights without being discriminated against.

EEA, UK, and Swiss Users: Our lawful bases for collecting and processing personal information under the GDPR include:
- Performing our contract with you and providing our services;
- Legitimate interests: we receive technical and interaction data of users, which may include IP addresses, to improve the security and reliability of our services and prevent abuse, and to understand where people learn about SketchWink; and
- Consent: where we ask for your consent to process your information, you can always withdraw this consent.

Under the GDPR, EEA, UK, and Swiss users have additional rights:
- The right to request correction or erasure of personal information;
- The right to object to processing your personal information;
- The right to transfer or receive a copy of the personal information in a usable and portable format, when any automated processing of personal data is based on your consent or a contract with you; and
- The right to withdraw your consent to processing, when the processing is based on your consent.

When we are processing data on behalf of another party that is the "data controller," you should direct your request to that party. You also have the right to lodge a complaint with a supervisory authority, but we encourage you to first contact us with any questions or concerns.

California Users: Under the CCPA, California residents have additional rights:
- The right to request personal information to be deleted, subject to several exceptions; and
- The right to opt out of the sale of personal information (note that we do not "sell" personal information as defined by the CCPA and have not done so in the past 12 months).

You may designate, in writing or through a power of attorney, an authorized agent to make requests on your behalf to exercise your rights under the CCPA. Before accepting such a request from an agent, we will require the agent to provide proof you have authorized it to act on your behalf, and we may need you to verify your identity directly with us. Further, to provide or delete specific pieces of personal information we will need to verify your identity to the degree of certainty required by law. We will verify your request by asking you to send it from the email address associated with your account or requiring you to provide information necessary to verify your account.

Changes
We may need to change this Privacy Policy and our notices from time to time. Any updates will be posted online with an effective date. Continued use of our Services after the effective date of any changes constitutes acceptance of those changes.

Contact Us
If you have questions about this Privacy Policy or wish to exercise your privacy rights, please contact us at:
SketchWink
Calle 12 Norte Esq. 70 Av #599
Cozumel, Quintana Roo, Mexico
Email: alejandro@sketchwink.com
"""#
    static let privacySpanish = #"""
SketchWink - Política de Privacidad
Última actualización y fecha de entrada en vigor: 26 de octubre de 2025

Nuestro compromiso con la privacidad y la protección de datos se refleja en esta Política de Privacidad, que describe cómo recopilamos y procesamos la "información personal" que te identifica, como tu nombre o dirección de correo electrónico. Cualquier otra información distinta de esta se considera "información no personal". Si almacenamos información personal junto con información no personal, consideraremos esa combinación como información personal.

Las referencias a nuestros "Servicios" en SketchWink (sketchwink.com) en esta declaración incluyen nuestro sitio web, aplicaciones y otros productos y servicios. Esta declaración se aplica a nuestros Servicios que muestran o hacen referencia a esta Política de Privacidad. Los servicios de terceros con los que nos integramos se rigen por sus propias políticas de privacidad.

Recopilación de Información
Obtenemos información sobre ti cuando nos la proporcionas directamente. Por ejemplo, recopilamos:
- Nombre e información de contacto. Recopilamos datos como el nombre y la dirección de correo electrónico.
- Información de pago. Si realizas una compra, recopilamos números de tarjetas de crédito, información de cuentas financieras y otros datos de pago.
- Contenido y archivos. Recopilamos y conservamos las fotos, documentos u otros archivos que nos envías en relación con la prestación de nuestros Servicios, incluso por correo electrónico o chat.

La recopilamos automáticamente a través de nuestros productos y servicios. Por ejemplo, recopilamos:
- Identificadores e información del dispositivo. Cuando visitas nuestros sitios web, nuestros servidores web registran tu dirección de Protocolo de Internet (IP) y la información sobre tu dispositivo, incluidos identificadores, tipo de dispositivo, sistema operativo, navegador y otro software, como tipo, versión, idioma, configuración y preferencias.
- Datos de geolocalización. Según la configuración de tu dispositivo y de la aplicación, recopilamos datos de geolocalización cuando utilizas nuestros Servicios.
- Datos de uso. Registramos tu actividad en nuestro sitio web, incluido el URL del sitio web desde el que llegaste a nuestro sitio, las páginas que viste en nuestro sitio web, cuánto tiempo pasaste en una página, los horarios de acceso y otros detalles sobre tu uso y acciones en nuestro sitio web. También recopilamos información sobre los elementos web u objetos con los que interactúas en nuestro Servicio, metadatos sobre tu actividad en el Servicio, cambios en tu estado de usuario y la duración de tu uso de nuestro Servicio.

Otras personas nos proporcionan información sobre ti. Las fuentes de terceros incluyen, por ejemplo:
- Socios externos. Aplicaciones y servicios de terceros, incluidas redes sociales con las que decidas conectarte o interactuar a través de nuestros Servicios.
- Proveedores de servicios. Terceros que recopilan o proporcionan datos en relación con el trabajo que realizan en nuestro nombre, por ejemplo compañías que determinan la ubicación de tu dispositivo a partir de su dirección IP.

Cuando intentamos comprender más sobre ti a partir de la información que nos has dado. Inferimos nueva información de otros datos que recopilamos, incluso mediante el uso de medios automatizados para generar información sobre tus probables preferencias u otras características ("inferencias"). Por ejemplo, inferimos tu ubicación geográfica general basándonos en tu dirección IP.

Uso de la Información
Usamos cada categoría de información personal sobre ti para:
- Proporcionarte nuestros Servicios;
- Mejorar y desarrollar nuestros Servicios;
- Comunicarnos contigo; y
- Brindarte soporte al cliente.

Compartición de Información
Compartimos información sobre ti:
- Cuando te hemos pedido y recibido tu consentimiento para compartirla;
- Cuando es necesario, incluso con proveedores de servicios externos, para procesar o brindar Servicios o productos para ti, pero solo si esas entidades aceptan proporcionar al menos el mismo nivel de protección de privacidad al que nos comprometemos en esta Política de Privacidad;
- Para cumplir con las leyes o responder a solicitudes y procesos legales válidos, siempre que te notifiquemos a menos que la ley nos lo prohíba. Solo divulgaremos información personal si creemos de buena fe que es legalmente obligatorio; y
- Solo si razonablemente creemos que es necesario para evitar daños a tus derechos, propiedad o seguridad o a los de otras personas.

En caso de una reestructuración corporativa o un cambio en nuestra estructura u organización, podemos divulgar información a un sucesor o afiliada.

Ten en cuenta que algunos de nuestros Servicios incluyen integraciones, referencias o enlaces a servicios proporcionados por terceros cuyas prácticas de privacidad difieren de las nuestras. Si proporcionas información personal a alguno de esos terceros, o si nos permites compartir información personal con ellos, esos datos se rigen por sus declaraciones de privacidad.

Finalmente, podemos compartir información no personal de conformidad con la ley aplicable.

Protección de la Información
Implementamos medidas de seguridad físicas, comerciales y técnicas para salvaguardar tu información personal. En caso de una violación de seguridad, te notificaremos para que puedas tomar las medidas de protección adecuadas. Solo conservamos tu información personal durante el tiempo necesario para cumplir la finalidad para la que la recopilamos. Después de eso, la eliminamos a menos que la ley nos obligue a conservarla.

Otra Información
Conservamos los datos personales durante el tiempo necesario para proporcionar los servicios y cumplir las transacciones que has solicitado, cumplir con nuestras obligaciones legales, resolver disputas, hacer cumplir nuestros acuerdos y otros fines comerciales legítimos y legales. Dado que estas necesidades pueden variar según el tipo de datos y el contexto de los servicios, los periodos reales de retención pueden variar notablemente en función de criterios como las expectativas del usuario o el consentimiento, la sensibilidad de los datos, la disponibilidad de controles automatizados que permitan a los usuarios eliminar datos y nuestras obligaciones legales o contractuales. Como parte de nuestras operaciones normales, tu información puede almacenarse en computadoras ubicadas en otros países fuera de tu país de residencia. Al proporcionarnos información, aceptas este tipo de transferencia de datos. Independientemente del lugar en que se almacene tu información, cumpliremos con la ley aplicable y respetaremos los compromisos aquí establecidos. No queremos tu información personal si eres menor de 13 años. No nos la proporciones. Si tu hijo es menor de 13 años y crees que nos ha proporcionado su información personal, contáctanos para eliminarla.

Usuarios del Espacio Económico Europeo, Reino Unido, Suiza y California
Los siguientes derechos se otorgan bajo el Reglamento General de Protección de Datos Europeo ("RGPD") y la Ley de Privacidad del Consumidor de California ("CCPA"). SketchWink aplica estos derechos a todos los usuarios de nuestros productos, independientemente de su ubicación:
- El derecho a saber qué información personal se recopila.
- El derecho a saber si la información personal se comparte y con quién.
- El derecho a acceder a tu información personal.
- El derecho a ejercer tus derechos de privacidad sin sufrir discriminación.

Usuarios del EEE, Reino Unido y Suiza: Nuestras bases legales para recopilar y procesar información personal según el RGPD incluyen:
- La ejecución de nuestro contrato contigo y la prestación de nuestros servicios;
- Intereses legítimos: recibimos datos técnicos e información de interacción de los usuarios, que pueden incluir direcciones IP, para mejorar la seguridad y confiabilidad de nuestros servicios y prevenir abusos, y para comprender cómo las personas conocen SketchWink; y
- Consentimiento: cuando solicitamos tu consentimiento para procesar tu información, siempre podrás retirarlo.

Según el RGPD, los usuarios del EEE, Reino Unido y Suiza tienen derechos adicionales:
- El derecho a solicitar la corrección o eliminación de información personal;
- El derecho a oponerse al procesamiento de tu información personal;
- El derecho a transferir o recibir una copia de la información personal en un formato utilizable y portátil, cuando cualquier procesamiento automatizado de datos personales se base en tu consentimiento o en un contrato contigo; y
- El derecho a retirar tu consentimiento para el procesamiento cuando dicho procesamiento se base en tu consentimiento.

Cuando procesemos datos en nombre de otra parte que es el "responsable del tratamiento", debes dirigir tu solicitud a dicha parte. También tienes derecho a presentar una reclamación ante una autoridad de control, pero te animamos a que primero nos contactes con cualquier pregunta o inquietud.

Usuarios de California: Según la CCPA, los residentes de California tienen derechos adicionales:
- El derecho a solicitar la eliminación de la información personal, sujeto a varias excepciones; y
- El derecho a optar por no vender información personal (ten en cuenta que no "vendemos" información personal según la definición de la CCPA y no lo hemos hecho en los últimos 12 meses).

Puedes designar, por escrito o mediante un poder notarial, a un agente autorizado para que presente solicitudes en tu nombre y ejerza tus derechos según la CCPA. Antes de aceptar una solicitud de un agente, exigiremos que el agente nos proporcione prueba de que lo has autorizado para actuar en tu nombre y es posible que necesitemos que verifiques tu identidad directamente con nosotros. Además, para proporcionar o eliminar información personal específica, necesitaremos verificar tu identidad con el grado de certeza que exija la ley. Verificaremos tu solicitud pidiéndote que la envíes desde la dirección de correo electrónico asociada con tu cuenta o solicitándote la información necesaria para verificar tu cuenta.

Cambios
Es posible que necesitemos modificar esta Política de Privacidad y nuestros avisos de vez en cuando. Cualquier actualización se publicará en línea con una fecha de entrada en vigor. El uso continuado de nuestros Servicios después de la fecha de entrada en vigor de cualquier cambio constituye la aceptación de dichos cambios.

Contáctanos
Si tienes preguntas sobre esta Política de Privacidad o deseas ejercer tus derechos de privacidad, contáctanos en:
SketchWink
Calle 12 Norte Esq. 70 Av #599
Cozumel, Quintana Roo, México
Correo electrónico: alejandro@sketchwink.com
"""#
}
