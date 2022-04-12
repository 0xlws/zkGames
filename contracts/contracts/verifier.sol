//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );

/*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }
    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-add-failed");
    }
    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length,"pairing-lengths-failed");
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-opcode-failed");
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}
contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            3069190857335566313689195551269230000626666612093139815011468776750102227112,
            8962627652965295437881074572294515128694777497383526765217248314313662580427
        );

        vk.beta2 = Pairing.G2Point(
            [7520334020013630833949534481174975443245230671155607135181528585490106003545,
             8577768575033325445470160147425091489453268321830474069356345248499303110879],
            [8400402192920567673013768905573822299816055318258678579298691870114397349101,
             11810672104943026377155576501126378786931550721547042954402414518268976403314]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [961892373409900816641678715115410233971046333571728317347807666934342644829,
             19859131586004548954566836766244147579978477047380034820024904538413322898869],
            [1479651886807491645335683733982017158057036465916927898500450519445081461705,
             4645236716451920400702316570762197827276780904122182662483945608170900290701]
        );
        vk.IC = new Pairing.G1Point[](82);
        
        vk.IC[0] = Pairing.G1Point( 
            1528591304651997036642400429490196012615000661259343797682650176962853346550,
            8515171195918043523738356253580093190532501110577576775696752928270200906629
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            14867085291150442298815961229064094877343783789745147154031519269959354753319,
            20538545204127565218506861283433841823711799538311319227552183988883439920442
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            917125246595570048797437577379168436379784482608952310516555583484205070403,
            21851895859517621130123797805051602279675425126880312820432626660492828971502
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            9650597070549141765035957667693305078777337039882927450152150568984870894305,
            18452825570976429404145866717297123324613397392823336013193487387620085529221
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            11993605847089178547865755498598446214516967471465959348077245452011124985562,
            16406505944725994815962611295811178875143695295084288332967337380451469478560
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            8364265654277219354673635760287241182962391918661543315171382554327777834231,
            1258471657145448192945080379224169155792636764829254281991425287096301869560
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            20142151618440683731236866837754296081778735965538585824031104574030595963172,
            3388569400924842985142472402438303598903031460427461585307303549415408331033
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            1851508180320820475488394597043248515975952458678765090283574393126342197384,
            7908224510448388425907358814925118585493028887225572898679183492139182887530
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            7992244697959365375776170974947284051124018280578787695522168386163195966901,
            3586447256621644758135627855401941061347769246508382758027903599193895566967
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            3435982158645210514596721716222290477992917593068989598284774850450222161528,
            11861147292733616497147498164967336196037238904920044700069459019631658811549
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            21737643121022245719371148538293556752589109830927103106753139288538735847924,
            19720132250454590301437343774496235765790751912825795755678814967523001772173
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            19528914382298135530574471827287295116716077254320417419227723229335796214950,
            13102409005089103438435746012756569738900093973838448107108223333104603018221
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            9617842557360645265217090013593281881911884216487506166547447208919138371218,
            8203467918589362207239389609849597286911052282467787099670983358827352835472
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            4504044344830888653411696581941432745136890723046559649793093663159664527524,
            11341804621012816785695555390011895355739024890160928222818397715112413150354
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            8112827170805802148731578941435520417444450637934683087467440479744246394256,
            13511095243612285076061929216784340745790972711506741805287363557972306343807
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            7401581852247189759944995428285688994706309873440348564120622550602364587046,
            19389541286016497256700359426720968009698403816502165208461577754016577218222
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            15633966632509960287992926824075027900381434094451546301879426716914975119871,
            7418380112551958825930939160204409988359883260915451578419148735868580503820
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            6118130849241603858348700277166753637365016355665180523616853957766713916686,
            21305016840484445949620759049438190805324905240055426651684734482214900007891
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            20720543377347006102866602748156167692904421645780556653723206507029203130235,
            17224900796176320239254849697966046275130270852562843891076211820194347990919
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            13560438128820704049347539521288407330724170095233650647562115486749405397068,
            14400008499739929901511801845421466166017884483556581682274372133912162391272
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            9513413570536025867670881272877322035666300258507463631002215192698693457761,
            12666668726943131542763500668511083352928489267401750500015910691563025500933
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            6364894506328616725736237226968483807183255239601844645849825399158546616504,
            6955917997732486987878949847144981898651949436030140756745023857017383147081
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            19162169754219319728337679204321210736823697840870549561975323369717145204325,
            8921905513319195231991011997045096640687308461394486617750232156845857246789
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            2646039398559610640250233922840197343377522722860930237777376871961550158989,
            1297692994352971451882152031604233048808989717746563665265234113784018074980
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            45627902598765500877271992130654425963756175518919148417222121197437295619,
            1308850343209774701962456260154589587580251370689087004244951190825993577722
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            13616526037033971399765845493110960662312019103512372996254650839305029979386,
            18506938585931674297490355547038134059625036570339892262085012981294361910819
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            12511696233129656007303070651247399200071847164017071513122249514672608023808,
            3828379609234633103933447680998623550802689910035207574616262940657135651779
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            15051326172575461443429356376130692116717830958654055316539760928883920314836,
            21335999452634266347252529920894944452102547435640611955860143057636318628309
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            11264014749244468575314592935908447026110805147933638265968811988734916588784,
            13520626452878020378085459093077316423862021676537210755718636218900782687647
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            12375979718657688946342046825046559173335311814333251838645406636032549066998,
            9294840527692517289600414329732856434966854153509396339414423025202204221967
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            19046346753833662214698745402661905846743021456242595387494989786090558700502,
            19046270306240659077391425866296367140607265550201133308939322448568125740874
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            12345763874344155824149882461501792226570429927930988058168136659895156130876,
            18348635287414150160124948491269653752948538519684691907582935776915542275185
        );                                      
        
        vk.IC[32] = Pairing.G1Point( 
            464874275120718417672267241035008058520726296057327453046560992092017972915,
            1864149286247588872524767251621177218373169923284321455774394936729374014867
        );                                      
        
        vk.IC[33] = Pairing.G1Point( 
            16823361273731063062728030708632410935557752301964573924282754306596103946671,
            17608689299471303895895913899876317188782760405055078976888169668422604707151
        );                                      
        
        vk.IC[34] = Pairing.G1Point( 
            17273525596894658376330123114138760693507053428144210757881393567385256359430,
            15664359967053831784701220858560848583388807715491401685450485046958221101062
        );                                      
        
        vk.IC[35] = Pairing.G1Point( 
            14623345982764358775694203046262416039998588555965010616215767986271735018062,
            11483391310492183391914537260575242656100910998227230605636614024709267436720
        );                                      
        
        vk.IC[36] = Pairing.G1Point( 
            18794621923510402475325201355683131810703315216812704679287577091557841113582,
            5095051164386715451151448196629978785816904348267858677345823842894245770365
        );                                      
        
        vk.IC[37] = Pairing.G1Point( 
            20305346052601467641189140349328376240484966562197451222587805015478249275123,
            20084363095765685343965961132863466313127448377246744662133169485207609295976
        );                                      
        
        vk.IC[38] = Pairing.G1Point( 
            4996516931797814675681960272984560392089578431686603536142703072124422533071,
            16706477782171427986327465802259856782643626334938793403568678149322615241889
        );                                      
        
        vk.IC[39] = Pairing.G1Point( 
            2863893997731037904599021635589791276868681381682807449502343674504787654459,
            21343330917769639441247601545961530363369625432500142169114915808950275026960
        );                                      
        
        vk.IC[40] = Pairing.G1Point( 
            12487411026953885809767331778162390172791115595450107591207279654562300129628,
            3740568788506160859147243628801241049410248503510373873700571179615547255333
        );                                      
        
        vk.IC[41] = Pairing.G1Point( 
            6399359071918467553998062344521794813326159741402047775241572298139887517131,
            20123548938443945921420631262523734102993985803761610950531612804298433751338
        );                                      
        
        vk.IC[42] = Pairing.G1Point( 
            4467642084555218935570385486587491736324995033005032125805356335820106951449,
            3199564658942853571191533656706675520893686142558769341920033062074693448348
        );                                      
        
        vk.IC[43] = Pairing.G1Point( 
            20125705634613617488077578689456442801149730525292404411981945618287528711522,
            5403694623971367050675741983274406224299536190570788321902621358047088876197
        );                                      
        
        vk.IC[44] = Pairing.G1Point( 
            20629356296396204385209268248950995520245240903452105292477311975119885532972,
            17400480976648674655499313583060794626556762050133459879837676964727139801259
        );                                      
        
        vk.IC[45] = Pairing.G1Point( 
            4457187278954330748326916425973126964535290892752879643226237855891497256400,
            4214415152658946731060799658247060781366368087171749803649190146076550555629
        );                                      
        
        vk.IC[46] = Pairing.G1Point( 
            8507307025646133808581673387734743945414770252151608043070674761272591458747,
            8819655944138467705913089069568157032018159600966764580749627182245154683253
        );                                      
        
        vk.IC[47] = Pairing.G1Point( 
            7486130198768266222098060609585287912115643822728151119410164003966707374531,
            4956560833710246087562870671708873297534142627949481144675960300095017023219
        );                                      
        
        vk.IC[48] = Pairing.G1Point( 
            18234231419715755087909901137413310684707813012598494146166857740881274080265,
            15909795009896233893590698044169446455204667507432631392014293574691173568263
        );                                      
        
        vk.IC[49] = Pairing.G1Point( 
            19744737311271029909308961974251737378675022132717755403004598483303646804071,
            9907933752652718348647500824111725770258789480120287021305025781380647875734
        );                                      
        
        vk.IC[50] = Pairing.G1Point( 
            15641883519062458720994928437795267208678574913043433229568455764877059972889,
            10189939987104792747968514778458005307747284461118223856556536837710926203639
        );                                      
        
        vk.IC[51] = Pairing.G1Point( 
            2408573707220847886484631141268165242719707610090449764699933747129961521806,
            9952060776903620528947184630369812685966935392486607160547709844500936419210
        );                                      
        
        vk.IC[52] = Pairing.G1Point( 
            7815708193215193727798002038800585749304350703772136536263618663497642436702,
            17897778529129583797978715569299575716133205613849918760882800133491097980148
        );                                      
        
        vk.IC[53] = Pairing.G1Point( 
            10008292301458253201433088983408809896043308702107205448823542199798825466467,
            8956402881189171459766254950752902378143130062632745134310859462958570694974
        );                                      
        
        vk.IC[54] = Pairing.G1Point( 
            9977040454719798902392909210756295838171991196035464658602908524413516833845,
            19009472693312033009301791429439030061292552347440637407166245721675770566850
        );                                      
        
        vk.IC[55] = Pairing.G1Point( 
            14975810404901212459322422132873145777432936284058083565818873020613151301116,
            9216251268606159919536690382982781824793291913108948379710138474260785804240
        );                                      
        
        vk.IC[56] = Pairing.G1Point( 
            21847031964211679502877644576342687734644056079682136159752280026732687750255,
            6511940121964104170923236066193499299742796177954993454789733851185041435365
        );                                      
        
        vk.IC[57] = Pairing.G1Point( 
            284089067966196969848412510479304986375260307396579312309166387509051638673,
            3104526321209625903279669376834935340471821603249185757770608753478680021429
        );                                      
        
        vk.IC[58] = Pairing.G1Point( 
            15466438021085670820990795895954086473794889542690829565959446829244557476836,
            12540091462719845621494182603691834446710314298388342286272837103238369215313
        );                                      
        
        vk.IC[59] = Pairing.G1Point( 
            14321764618681797731709779668904437862234315127673523771257610876627995697177,
            15368603946874217655459348370328695717267396872586207981587998030328843517869
        );                                      
        
        vk.IC[60] = Pairing.G1Point( 
            7254062991983467921800616032340701740205282874112383503687449496302696400420,
            11055241785148288378504492904228829448990742789849403771483655408514081380518
        );                                      
        
        vk.IC[61] = Pairing.G1Point( 
            2655910433606658732342138219672724312923234148542392979457646886930995620141,
            9305260989538016222277327185793493050285996978357903052162940257239942970474
        );                                      
        
        vk.IC[62] = Pairing.G1Point( 
            3703165119721048114750980571528118613160783510461246474249600276054864579134,
            11358555865439361678170676503243848792257271201105544730022145441189604795280
        );                                      
        
        vk.IC[63] = Pairing.G1Point( 
            4244247116530535051727848091867827672200031602360935030921677011054692174296,
            17927699385927612087753411450714145158086863607125291389637451696388330642800
        );                                      
        
        vk.IC[64] = Pairing.G1Point( 
            13214315475135150207153990764745451796999959244279203903799061126675322812242,
            5052248206096042173968649092736582120132688711242886189605618688975787184551
        );                                      
        
        vk.IC[65] = Pairing.G1Point( 
            9867160185292490555277622517507268197023199896190328835303917258748381315165,
            12130728591305875148085642649572741512826565181714957240236785797499166089178
        );                                      
        
        vk.IC[66] = Pairing.G1Point( 
            1981721847680540227698561410114524708231886763345595717111213820790818038468,
            9905170730997349293607941867372586293812327176526602435346269406437161786
        );                                      
        
        vk.IC[67] = Pairing.G1Point( 
            697203991462044111750605634578234674441298000668980586503902179428727436071,
            2046913581137385116718112145263285244416074454832568157499066195866752788536
        );                                      
        
        vk.IC[68] = Pairing.G1Point( 
            6350292167239700419790492105939754901775760675900597018609057308113714282016,
            2950642744878329307114318970448443106794360070299151130091866069899391869532
        );                                      
        
        vk.IC[69] = Pairing.G1Point( 
            6060668514253108521947146382698087435703155774003264903558523041334343464652,
            17764668411605999501365026132145336538164757642780238303802865786581240354748
        );                                      
        
        vk.IC[70] = Pairing.G1Point( 
            5100170591413478452828565071645146219287238777673718320618999717164051714433,
            18723527145718004810172241908236639978111197823590835763226223068223747434872
        );                                      
        
        vk.IC[71] = Pairing.G1Point( 
            6187623938412954434772558759130526984059108898070464078681724051295699065336,
            20370542611375764814636748560420415323310473217941461780987339013953411281285
        );                                      
        
        vk.IC[72] = Pairing.G1Point( 
            10933884241432968701900867083329179074693808658933964528825117425297545402092,
            16422109397515026072003913007675014916717033088996737333793370872856853107264
        );                                      
        
        vk.IC[73] = Pairing.G1Point( 
            10204247889247499361200779437776072135860652759597625413369035724691670748810,
            3023023701963364485511868858252675401323627747469167578338680116909086745319
        );                                      
        
        vk.IC[74] = Pairing.G1Point( 
            9977564495787065537461896426307221370487936314063825363891033467999327716323,
            20621117658062097762946820840812190207603631154466588842943016988249028043807
        );                                      
        
        vk.IC[75] = Pairing.G1Point( 
            11853485397364759864994543145159935458399314275028472544256351013342170634918,
            1488247387476540492047357022623145464477297166836151578864352998311893777781
        );                                      
        
        vk.IC[76] = Pairing.G1Point( 
            1160684249923510242355735143543412934537480695512770977648190979622380035021,
            3634811888316480944516784730001253287439063055206470176518828671236571841403
        );                                      
        
        vk.IC[77] = Pairing.G1Point( 
            5124857654140830651737623797466536583607613123288503472674266852385557397327,
            7885397414237769724399322968440932556484942493505117061857821505486523407238
        );                                      
        
        vk.IC[78] = Pairing.G1Point( 
            12399416287805366810842897960262918931576393956489856740238068667616256912151,
            9281036851637775186969225129504481598977692649098055974790104379884374154317
        );                                      
        
        vk.IC[79] = Pairing.G1Point( 
            5654972632432287218104330448255877079465655539815941033709807634213832815335,
            20042072108993570176278364691085013124744163632612183192731281154329431826698
        );                                      
        
        vk.IC[80] = Pairing.G1Point( 
            19802137469082952194299139740769857262945930456929891792047772792631410381328,
            15659463321628401629398129647544953748268402543692193691327524782552698210287
        );                                      
        
        vk.IC[81] = Pairing.G1Point( 
            21448673215352461445665445009180258144175775115776034611190168902232721109983,
            5706787258424478797055187817003394648554878064365168094258000744623699474867
        );                                      
        
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[81] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
