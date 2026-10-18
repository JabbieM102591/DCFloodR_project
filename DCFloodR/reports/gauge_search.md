# Search for water-level gauges inside Washington, DC

## Method

1. USGS: site catalogue searched inside the DC bounding box (old waterservices site service and the new Water Data API monitoring-locations collection), plus a short list of known candidate ids.
2. NOAA CO-OPS: list of all water-level stations, filtered to the DC box.
3. Every candidate is tested against the DC outline (point-in-polygon). Only gauges **inside** the outline are used; others are listed as nearby.
4. DC outline: OpenStreetMap Nominatim polygon for the District of Columbia, retrieved 2026-10-18T01:08:54Z

- legacy site search: ok; 21 site(s) returned
- Water Data API monitoring-locations search: ok; 170 site(s) returned

## USGS candidates

| site | name | lat | lon | found by | inside DC outline |
|---|---|---|---|---|---|
| 01647600 | POTOMAC RIVER AT WISCONSIN AVE, WASHINGTON, DC | 38.9033611 | -77.0676667 | legacy site service | **yes** |
| 01648000 | ROCK CREEK AT SHERRILL DRIVE WASHINGTON, DC | 38.9725 | -77.04 | legacy site service | **yes** |
| 01648010 | Rock Creek at Joyce Rd Washington, DC | 38.960167 | -77.042056 | legacy site service | **yes** |
| 01648011 | Luzon Branch above Rock Creek at Washington DC | 38.96169444 | -77.04138889 | legacy site service | **yes** |
| 01649500 | NORTHEAST BRANCH ANACOSTIA RIVER AT RIVERDALE, MD | 38.96025 | -76.9259722 | legacy site service | no (nearby only) |
| 01650800 | SLIGO CREEK NEAR TAKOMA PARK, MD | 38.9862222 | -77.0048611 | legacy site service | no (nearby only) |
| 01651000 | NORTHWEST BR ANACOSTIA RIVER NR HYATTSVILLE, MD | 38.95255556 | -76.96513889 | legacy site service | no (nearby only) |
| 01651003 | NORTHWEST BRANCH ANACOSTIA RIVER AT BRENTWOOD, MD | 38.9489722 | -76.9562222 | legacy site service | no (nearby only) |
| 01651007 | ANACOSTIA RIVER AT BLADENSBURG WATERFRONT PARK, MD | 38.93416667 | -76.93925 | legacy site service | no (nearby only) |
| 01651730 | BEAVERDAM CREEK NEAR CHEVERLY, MD | 38.91630556 | -76.9343056 | legacy site service | no (nearby only) |
| 01651750 | ANACOSTIA RIVER AQUATIC GARDENS AT WASHINGTON, DC | 38.9145 | -76.9505 | legacy site service | **yes** |
| 01651760 | ANACOSTIA RIVER AT KENILWORTH AT WASHINGTON, DC | 38.90916667 | -76.95527778 | legacy site service | **yes** |
| 01651770 | HICKEY RUN AT NATIONAL ARBORETUM AT WASHINGTON, DC | 38.9161111 | -76.9688611 | legacy site service | **yes** |
| 01651800 | WATTS BRANCH AT WASHINGTON, DC | 38.90127778 | -76.94327778 | legacy site service | **yes** |
| 01651812 | ANACOSTIA RIVER AT ANACOSTIA PARK BOAT RAMP, DC | 38.87991667 | -76.9708333 | legacy site service | **yes** |
| 01651827 | Anacostia River nr Buzzard Point at Washington, DC | 38.86516667 | -77.0103333 | legacy site service | **yes** |
| 01652500 | FOURMILE RUN AT ALEXANDRIA, VA | 38.8433333 | -77.0858611 | legacy site service | no (nearby only) |
| 01652545 | FOURMILE RUN ABOVE HIGHWAY 1 AT ALEXANDRIA, VA | 38.8402222 | -77.0533056 | legacy site service | no (nearby only) |
| 0165258890 | POTOMAC RIVER AT CAMERON ST DOCK AT ALEXANDRIA, VA | 38.80527778 | -77.0383333 | legacy site service | no (nearby only) |
| 01653000 | CAMERON RUN AT ALEXANDRIA, VA | 38.8044466 | -77.10558989 | legacy site service | no (nearby only) |
| 01653620 | MEETINGHOUSE BRANCH AT CAMP SPRINGS, MD | 38.79841667 | -76.90225 | legacy site service | no (nearby only) |
| 385353076573301 | DC90S001 | 38.8981674463929 | -76.9588636539185 | Water Data API monitoring-locations | **yes** |
| 01646550 | LITTLE FALLS BRANCH NEAR BETHESDA, MD | 38.9576106143618 | -77.1083117719245 | Water Data API monitoring-locations | no (nearby only) |
| 01646563 | MILL CREEK TRIB NR DALECARLIA RES AT WASHINGTON DC | 38.9455555555556 | -77.1044444444444 | Water Data API monitoring-locations | **yes** |
| 01646564 | MILL CREEK AT DALECARLIA RES NEAR CHEVY CHASE, MD | 38.9456388888889 | -77.1078888888889 | Water Data API monitoring-locations | no (nearby only) |
| 01646565 | EAST CREEK NR DALECARLIA RES AT WASHINGTON, DC | 38.9397777777778 | -77.1053055555555 | Water Data API monitoring-locations | **yes** |
| 0164656550 | EAST CREEK TRIB NR DALECARLIA RES AT WASHINGTON DC | 38.9397222222222 | -77.1052777777778 | Water Data API monitoring-locations | **yes** |
| 01646566 | EAST CREEK AT DALECARLIA RES AT WASHINGTON, DC | 38.9427777777778 | -77.1085 | Water Data API monitoring-locations | **yes** |
| 01646567 | EAST CREEK AT DALECARLIA RES NEAR CHEVY CHASE, MD | 38.9456388888889 | -77.1078888888889 | Water Data API monitoring-locations | no (nearby only) |
| 01646568 | MILL CREEK AT DALECARLIA RES NEAR BETHESDA, MD | 38.946 | -77.1085 | Water Data API monitoring-locations | no (nearby only) |
| 01646569 | MILL CREEK AT DALECARLIA RES AT BROOKMONT, MD | 38.9451388888889 | -77.1119444444444 | Water Data API monitoring-locations | no (nearby only) |
| 01646580 | POTOMAC RIVER AT CHAIN BRIDGE, AT WASHINGTON, DC | 38.9295555317606 | -77.1169231550794 | Water Data API monitoring-locations | no (nearby only) |
| 01647500 | DONALDSON RUN AT MILITARY RD AT ARLINGTON, VA | 38.9112225198222 | -77.1135898045247 | Water Data API monitoring-locations | no (nearby only) |
| 01647505 | POTOMAC RIVER TRIBUTARY AT WASHINGTON, DC | 38.9215001432107 | -77.0977560743745 | Water Data API monitoring-locations | **yes** |
| 01647595 | POTOMAC RIVER AT KEY BRIDGE AT WASHINGTON, DC | 38.9023338527258 | -77.0694220927543 | Water Data API monitoring-locations | **yes** |
| 01647994 | ROCK CREEK AT MD/DC BOUNDRY AT WASHINGTON DC | 38.9866666666667 | -77.0527777777778 | Water Data API monitoring-locations | **yes** |
| 01647996 | TRIB TO FENWICK BR AT RED BUD LANE, WASHINGTON DC | 38.9930555555556 | -77.0447222222222 | Water Data API monitoring-locations | no (nearby only) |
| 01647997 | PORTAL BRANCH AT NORTH PORTAL DR, WASHINGTON, DC | 38.9894444444444 | -77.0425 | Water Data API monitoring-locations | **yes** |
| 0164799789 | FENWICK BRANCH ABOVE ROCK CREEK AT WASHINGTON DC | 38.9841666666667 | -77.0422222222222 | Water Data API monitoring-locations | **yes** |
| 0164799790 | STORM SEWER FL TO ROCK CR BL FENWICK BR WASH DC | 38.9836111111111 | -77.0416666666667 | Water Data API monitoring-locations | **yes** |
| 01647998 | ROCK CREEK BELOW WEST BEACH DRIVE WASHINGTON, DC | 38.9829991453032 | -77.0399492965239 | Water Data API monitoring-locations | **yes** |
| 01648001 | Whittier Run above Rock Creek at Washington DC | 38.9719444444444 | -77.0397222222222 | Water Data API monitoring-locations | **yes** |
| 01648002 | Pinehurst Branch above Barnaby St at Washington DC | 38.9783333333333 | -77.0588888888889 | Water Data API monitoring-locations | **yes** |
| 01648003 | Pinehurst Br trib nr Barnaby St at Washington DC | 38.9780555555556 | -77.0588888888889 | Water Data API monitoring-locations | **yes** |
| 01648004 | PINEHURST BRANCH AT OREGON AVENUE WASHINGTON, DC | 38.9764159135026 | -77.0517272906957 | Water Data API monitoring-locations | **yes** |
| 01648005 | PINEHURST BRANCH AT BEACH DRIVE, WASHINGTON, DC | 38.9714166666667 | -77.0437222222222 | Water Data API monitoring-locations | **yes** |
| 0164800550 | Rock Creek trib near Bingham Dr at Washington DC | 38.9688888888889 | -77.0469444444444 | Water Data API monitoring-locations | **yes** |
| 01648006 | ROCK CREEK TRIBUTARY AT GOLF COURSE WASHINGTON, DC | 38.9668605329575 | -77.0458938314029 | Water Data API monitoring-locations | **yes** |
| 01648015 | BROAD BRANCH AT WASHINGTON, DC | 38.9514996826733 | -77.0527550657604 | Water Data API monitoring-locations | **yes** |
| 0164801540 | Broad Branch above Soapstone Valley at Wash DC | 38.9455555555556 | -77.0513888888889 | Water Data API monitoring-locations | **yes** |
| 0164801550 | Soapstone Valley trib to Broad Branch at Wash DC | 38.945 | -77.0519444444444 | Water Data API monitoring-locations | **yes** |
| 01648016 | ROCK CREEK AT PIERCE MILL WASHINGTON, DC | 38.9378055555555 | -77.0518888888889 | Water Data API monitoring-locations | **yes** |
| 01648100 | Rock Creek above Piney Branch at Washington DC | 38.9352777777778 | -77.0477777777778 | Water Data API monitoring-locations | **yes** |
| 01648200 | Piney Branch above Rock Creek at Washinton DC | 38.9352777777778 | -77.0469444444444 | Water Data API monitoring-locations | **yes** |
| 01648300 | Rock Cr above Connecticut Av at Washington DC | 38.9230555555555 | -77.0486111111111 | Water Data API monitoring-locations | **yes** |
| 01648390 | Normanstone Creek above Rock Creek at WashingtonDC | 38.9188888888889 | -77.0561111111111 | Water Data API monitoring-locations | **yes** |
| 01648450 | Dumbarton Oaks trib above Rock Cr at Washington DC | 38.9155555555556 | -77.0594444444444 | Water Data API monitoring-locations | **yes** |
| 01648500 | Rock Creek below Dumbarton Oaks trib at Wash DC | 38.9147222222222 | -77.0583333333333 | Water Data API monitoring-locations | **yes** |
| 01648998 | ROCK CREEK ABOVE Q STREET WASHINGTON, DC | 38.9117226042638 | -77.0516994491269 | Water Data API monitoring-locations | **yes** |
| 01649000 | ROCK CREEK AT Q STREET, WASHINGTON  DC | 38.9112226135392 | -77.0513661074035 | Water Data API monitoring-locations | **yes** |
| 01649003 | Pipe inflow to Rock Cr below P St at Washington DC | 38.9088888888889 | -77.0502777777778 | Water Data API monitoring-locations | **yes** |
| 01649010 | Rock Creek above M Street at Washington DC | 38.9013888888889 | -77.0583333333333 | Water Data API monitoring-locations | **yes** |
| 01649025 | WASHINGTON CHANNEL AT WASHINGTON, DC | 38.8755833333333 | -77.0250555555556 | Water Data API monitoring-locations | **yes** |
| 01650900 | SLIGO CREEK AT TAKOMA PARK, MD | 38.9831658561305 | -77.0002541018525 | Water Data API monitoring-locations | no (nearby only) |
| 01651010 | ANACOSTIA RIVER AT BLADENSBURG, MD | 38.9237225680186 | -76.938585389827 | Water Data API monitoring-locations | no (nearby only) |
| 01651720 | CABIN BRANCH NEAR 64TH STREET AT CHEVERLY, MD | 38.9157777777778 | -76.9117777777778 | Water Data API monitoring-locations | no (nearby only) |
| 01651725 | BEAVERDAM CREEK AT CHEVERLY, MD | 38.9141111111111 | -76.9211111111111 | Water Data API monitoring-locations | no (nearby only) |
| 01651740 | NASH RUN AT WASHINGTON, DC | 38.9103333333333 | -76.9421111111111 | Water Data API monitoring-locations | **yes** |
| 01651780 | HICKEY RUN AT WASHINGTON, DC | 38.912333843606 | -76.9649749973847 | Water Data API monitoring-locations | **yes** |
| 01651793 | WATTS BRANCH AT 50TH ST, WASHINGTON, DC | 38.89775 | -76.9284166666667 | Water Data API monitoring-locations | **yes** |
| 01651794 | WATTS BRANCH AT 49TH ST, WASHINGTON DC | 38.8982222222222 | -76.93225 | Water Data API monitoring-locations | **yes** |
| 01651795 | WATTS BRANCH AT BENNING ROAD, WASHINGTON, DC | 38.897889723432 | -76.9330295788798 | Water Data API monitoring-locations | **yes** |
| 01651805 | WATTS BRANCH NEAR WASHINGTON, DC | 38.9067784184302 | -76.9488634002882 | Water Data API monitoring-locations | **yes** |
| 01651810 | UNMED TRIB TO ANACOSTIA R BLW FT DUPONT AT WASH DC | 38.8821111111111 | -76.964 | Water Data API monitoring-locations | **yes** |
| 01651815 | POPE BRANCH AT WASHINGTON, DC | 38.8734456775391 | -76.9580301990129 | Water Data API monitoring-locations | **yes** |
| 01651817 | POPE BRANCH AT FAIRLAWN AVE AT WASHINGTON, DC | 38.8776 | -76.9666194444444 | Water Data API monitoring-locations | **yes** |
| 01651825 | ANACOSTIA RIVER AT WASHINGTON, DC | 38.8792788756451 | -76.9713639347082 | Water Data API monitoring-locations | **yes** |
| 0165182550 | TRIB TO ANACOSTIA R ABV GOOD HOPE ROAD AT WASH, DC | 38.8639166666667 | -76.9765833333333 | Water Data API monitoring-locations | **yes** |
| 01652430 | DOCTORS RUN AT ARLINGTON, VA | 38.8617789490187 | -77.1022007637964 | Water Data API monitoring-locations | no (nearby only) |
| 01652470 | LUCKY RUN AT ARLINGTON, VA | 38.8426126108396 | -77.1041453090135 | Water Data API monitoring-locations | no (nearby only) |
| 01652507 | FOURMILE RUN AT EAST GLEBE ROAD AT ALEXANDRIA, VA | 38.8437237513797 | -77.0772001018368 | Water Data API monitoring-locations | no (nearby only) |
| 01652525 | LONG BRANCH AT SOUTH GLEBE ROAD NR ALEXANDRIA, VA | 38.8445570812003 | -77.0710888181072 | Water Data API monitoring-locations | no (nearby only) |
| 01652570 | POTOMAC RIVER AT BLUE PLAINS PIER, WASHINGTON, DC | 38.8126111111111 | -77.0270277777778 | Water Data API monitoring-locations | **yes** |
| 01652580 | OXON RUN AT 13TH STREET AT WASHINGTON, DC | 38.8390017822692 | -76.9885864731565 | Water Data API monitoring-locations | **yes** |
| 0165258850 | OXON RUN NEAR WASHINGTON, DC | 38.8503905384505 | -76.9599746070144 | Water Data API monitoring-locations | no (nearby only) |
| 0165258860 | OXON RUN AT WASHINGTON, DC | 38.8398351101261 | -76.9849752645961 | Water Data API monitoring-locations | **yes** |
| 01652589 | POTOMAC RIVER BEL OXON CREEK AT WASHINGTON, DC | 38.8017801394568 | -77.0263652229643 | Water Data API monitoring-locations | **yes** |
| 0165258970 | POTOMAC RIV AT CST GUARD DOCK AT ALEXANDRIA, VA | 38.79650242912 | -77.0391433872756 | Water Data API monitoring-locations | no (nearby only) |
| 01652590 | POTOMAC RIVER AT ALEXANDRIA, VA | 38.7928913855247 | -77.0371988748478 | Water Data API monitoring-locations | no (nearby only) |
| 01652688 | HOLMES RUN ALONG HOLMES RUN PKWY AT ALEXANDRIA, VA | 38.8152777777778 | -77.12 | Water Data API monitoring-locations | no (nearby only) |
| 01652690 | HOLMES RUN AT ALEXANDRIA, VA | 38.8123353383621 | -77.1138679020399 | Water Data API monitoring-locations | no (nearby only) |
| 01653002 | CAMERON RUN AB SOUTH QUAKER LANE AT ALEXANDRIA, VA | 38.8042799549536 | -77.0972007469937 | Water Data API monitoring-locations | no (nearby only) |
| 01653004 | CAMERON RUN AT SOUTH QUAKER LANE AT ALEXANDRIA, VA | 38.8042799736676 | -77.0877560113453 | Water Data API monitoring-locations | no (nearby only) |
| 01653210 | PIKE BRANCH AT ALEXANDRIA, VA | 38.7931690642009 | -77.0835892289641 | Water Data API monitoring-locations | no (nearby only) |
| 01653213 | PIKE BRANCH AT EAST DR AT ALEXANDRIA, VA | 38.798724528635 | -77.0808113581304 | Water Data API monitoring-locations | no (nearby only) |
| 01653215 | CAMERON RUN AT TELEGRAPH RD AT ALEXANDRIA, VA | 38.7987245314214 | -77.079422425903 | Water Data API monitoring-locations | no (nearby only) |
| 01653410 | TAYLOR RUN AT ALEXANDRIA, VA | 38.8084465929732 | -77.0749778371935 | Water Data API monitoring-locations | no (nearby only) |
| 01653415 | CAMERON RUN BELOW TELEGRAPH RD AT ALEXANDRIA, VA | 38.798446770751 | -77.073311124231 | Water Data API monitoring-locations | no (nearby only) |
| 01653445 | HUNTING CREEK AT HWY 1 AT ALEXANDRIA, VA | 38.7926135731018 | -77.0566439334131 | Water Data API monitoring-locations | no (nearby only) |
| 384724076542301 | TINKERS CR NEAR BERKSHIRE DR AT JENKINS CORNER, MD | 38.79 | -76.9063333333333 | Water Data API monitoring-locations | no (nearby only) |
| 384749077022500 | POTOMAC RIVER AT FORDS LANDING AT ALEXANDRIA, VA | 38.7969444444444 | -77.0402777777778 | Water Data API monitoring-locations | no (nearby only) |
| 384755077022600 | POTOMAC RIVER NEAR MARINA PARK AT ALEXANDRIA, VA | 38.7986111111111 | -77.0405555555556 | Water Data API monitoring-locations | no (nearby only) |
| 384802077022200 | POTOMAC RIVER AT WOLFE STREET AT ALEXANDRIA, VA | 38.8005555555556 | -77.0394444444444 | Water Data API monitoring-locations | no (nearby only) |
| 384811077022100 | POTOMAC RIVER AT PRINCE STREET AT ALEXANDRIA, VA | 38.8030555555556 | -77.0391666666667 | Water Data API monitoring-locations | no (nearby only) |
| 384815077011001 | POTOMAC RIVER AT BLUE PLAINS | 38.812613262037 | -77.0363655546306 | Water Data API monitoring-locations | **yes** |
| 384815077022200 | POTOMAC RIVER AT 2 KING STREET AT ALEXANDRIA, VA | 38.8041666666667 | -77.0394444444444 | Water Data API monitoring-locations | no (nearby only) |
| 384816077022500 | POTOMAC RIVER AT 101 KING ST AT ALEXANDRIA, VA | 38.8044444444444 | -77.0402777777778 | Water Data API monitoring-locations | no (nearby only) |
| 384823077022000 | POTOMAC R AT FOUNDERS PARK DOCK AT ALEXANDRIA, VA | 38.8063888888889 | -77.0388888888889 | Water Data API monitoring-locations | no (nearby only) |
| 384823077022300 | POTOMAC RIVER AT FOUNDERS PARK AT ALEXANDRIA, VA | 38.8063888888889 | -77.0397222222222 | Water Data API monitoring-locations | no (nearby only) |
| 384844077021800 | POTOMAC RIVER AT 100 MADISON ST AT ALEXANDRIA, VA | 38.8122222222222 | -77.0383333333333 | Water Data API monitoring-locations | no (nearby only) |
| 384844077022200 | POTOMAC RIVER AT 120 MADISON ST AT ALEXANDRIA, VA | 38.8122222222222 | -77.0394444444444 | Water Data API monitoring-locations | no (nearby only) |
| 384852077014000 | BLUE PLAINS SEWAGE TREATMENT PLANT | 38.8145576894375 | -77.0274764016468 | Water Data API monitoring-locations | **yes** |
| 384852077014001 | BLUE PLAINS SEWAGE TREATMENT PLANT OUTFALL 001 | 38.8145576894375 | -77.0274764016468 | Water Data API monitoring-locations | **yes** |
| 384852077014002 | BLUE PLAINS SEWAGE TREATMENT PLANT OUTFALL 002 | 38.8145576894375 | -77.0274764016468 | Water Data API monitoring-locations | **yes** |
| 384852077020500 | POTOMAC RIVER AT MARBURY POINT | 38.8145576759945 | -77.0344210554535 | Water Data API monitoring-locations | **yes** |
| 384900077020000 | POTOMAC RIVER LAGRANGIAN SHALLOW | 38.8167798617284 | -77.0330321296303 | Water Data API monitoring-locations | **yes** |
| 384900077021000 | POTOMAC RIVER LAGRANGIAN CHANNEL | 38.8167798563786 | -77.0358099907415 | Water Data API monitoring-locations | **yes** |
| 385001076545801 | UNNAMED TRIB TO HENSON CREEK AT SUITLAND, MD | 38.8334833333333 | -76.9161222222222 | Water Data API monitoring-locations | no (nearby only) |
| 385039077012600 | POTOMAC RIVER AT GEISBORO POINT | 38.8442793969546 | -77.0219207666656 | Water Data API monitoring-locations | **yes** |
| 385130077014501 | POTOMAC RIVER AT HAINS POINT | 38.8601124306296 | -77.0333100112329 | Water Data API monitoring-locations | **yes** |
| 385138077014000 | POTOMAC RIVER BUOY 4   HAINES PT. | 38.8606679864883 | -77.0274765211915 | Water Data API monitoring-locations | **yes** |
| 385141077015000 | POTOMAC RIVER AT DANGERFIELD ISLAND | 38.861501300312 | -77.0302543761813 | Water Data API monitoring-locations | **yes** |
| 385205077015500 | POTOMAC RIVER BUOY 6   HAINES PT. | 38.8681678470078 | -77.0316433180277 | Water Data API monitoring-locations | **yes** |
| 385216077011000 | POTOMAC RIVER, WASHINGTON CH AT FT MC NAIR | 38.8712233697255 | -77.0191429954706 | Water Data API monitoring-locations | **yes** |
| 385218077001801 | Anacostia River at Diamond Teague Park, DC | 38.8715888888889 | -77.0048805555556 | Water Data API monitoring-locations | **yes** |
| 385223077022400 | POTOMAC RIVER AT 14TH STREET BR WASH DC | 38.8731677453333 | -77.039699096541 | Water Data API monitoring-locations | **yes** |
| 385224076590301 | Anacostia River at Fairlawn, DC | 38.8734111111111 | -76.9841888888889 | Water Data API monitoring-locations | **yes** |
| 385315077031800 | POTOMAC RIVER AT MEMORIAL BRIDGE | 38.8884452336832 | -77.0524772237628 | Water Data API monitoring-locations | **yes** |
| 385348076574501 | Anacostia River at Benning, DC | 38.8966305555556 | -76.9624805555556 | Water Data API monitoring-locations | **yes** |
| 385422077052001 | Potomac River Bed Sediment WP022 | 38.9061111111111 | -77.0888888888889 | Water Data API monitoring-locations | **yes** |
| 385424077051901 | Potomac River Bed Sediemnt WP019 | 38.9066666666667 | -77.0886111111111 | Water Data API monitoring-locations | **yes** |
| 385424077053301 | Potomac River Bed Sediment WP004 | 38.9066666666667 | -77.0925 | Water Data API monitoring-locations | **yes** |
| 385426077053401 | Potomac R Bed Sediment WP003 | 38.9072222222222 | -77.0927777777778 | Water Data API monitoring-locations | **yes** |
| 385428077053401 | Potomac R Bed Sediment WP002 | 38.9077777777778 | -77.0927777777778 | Water Data API monitoring-locations | **yes** |
| 385432077054301 | Potomac R Bed Sediment WP005 | 38.9088888888889 | -77.0952777777778 | Water Data API monitoring-locations | **yes** |
| 385434077054801 | Potomac R Bed Sediment WP007 | 38.9094444444444 | -77.0966666666667 | Water Data API monitoring-locations | **yes** |
| 385435077055001 | Potomac R Bed Sediment WP008 | 38.9097222222222 | -77.0972222222222 | Water Data API monitoring-locations | **yes** |
| 385436077054701 | Potomac R Bed Sediment WP006 | 38.91 | -77.0963888888889 | Water Data API monitoring-locations | **yes** |
| 385439077055201 | Potomac R Bed Sediment WP009 | 38.9108333333333 | -77.0977777777778 | Water Data API monitoring-locations | **yes** |
| 385440077055501 | Potomac River Sed near Georgetown Res. | 38.9111111111111 | -77.0986111111111 | Water Data API monitoring-locations | **yes** |
| 385441077055601 | Potomac R Bed Sediment WP010 | 38.9113888888889 | -77.0988888888889 | Water Data API monitoring-locations | **yes** |
| 385443077060101 | Potomac River Bed Sediment - DC01 | 38.9119722222222 | -77.1003333333333 | Water Data API monitoring-locations | **yes** |
| 385446077060301 | Potomac R Bed Sediment WP011 | 38.9127777777778 | -77.1008333333333 | Water Data API monitoring-locations | **yes** |
| 385457077060701 | Potomac R Bed Sediment WP012 | 38.9158333333333 | -77.1019444444444 | Water Data API monitoring-locations | **yes** |
| 385511077062501 | Potomac R Bed Sediment WP014 | 38.9197222222222 | -77.1069444444444 | Water Data API monitoring-locations | **yes** |
| 385513077062001 | Potomac R Bed Sediment WP013 | 38.9202777777778 | -77.1055555555556 | Water Data API monitoring-locations | **yes** |
| 385516077062401 | Potomac R Bed Sediment WP015 | 38.9211111111111 | -77.1066666666667 | Water Data API monitoring-locations | **yes** |
| 385519077063201 | Potomac R Bed Sediment WP016 | 38.9219444444444 | -77.1088888888889 | Water Data API monitoring-locations | **yes** |
| 385527077063701 | Potomac R Bed Sediment WP017 | 38.9241666666667 | -77.1102777777778 | Water Data API monitoring-locations | **yes** |
| 385612077065104 | Dalecarlia Reservoirs, Basin 4, near Washington DC | 38.9366388888889 | -77.1141666666667 | Water Data API monitoring-locations | **yes** |
| 385619077063601 | Spring 1 at Dalecarlia Reservoir | 38.9386111111111 | -77.11 | Water Data API monitoring-locations | **yes** |
| 385620077062201 | SW-7 | 38.9388888888889 | -77.1061111111111 | Water Data API monitoring-locations | **yes** |
| 385634077063201 | Res-1 | 38.9427777777778 | -77.1088888888889 | Water Data API monitoring-locations | **yes** |
| 385716077031201 | WEST SPRING, DC | 38.9544444444444 | -77.0527777777778 | Water Data API monitoring-locations | **yes** |
| 385718077030101 | MAINTENANCE YARD STREAM, WASHINGTON, DC | 38.9558333333333 | -77.0530555555556 | Water Data API monitoring-locations | **yes** |
| 385725077023801 | PICNIC 21, DC | 38.9569444444444 | -77.0438888888889 | Water Data API monitoring-locations | **yes** |
| 385730077023001 | MAINTENANCE POND, WASHINGTON, DC | 38.9583652876795 | -77.041342674939 | Water Data API monitoring-locations | **yes** |
| 385755077023001 | FAIRWAY18, DC | 38.9652777777778 | -77.0416666666667 | Water Data API monitoring-locations | **yes** |
| 385759077024301 | GOLF COURSE I, DC | 38.9666666666667 | -77.0463888888889 | Water Data API monitoring-locations | **yes** |
| 385813077030801 | BINGHAM/OREGON | 38.9702777777778 | -77.0525 | Water Data API monitoring-locations | **yes** |
| 385817077021301 | WHITTIER, DC | 38.9716666666667 | -77.0369444444444 | Water Data API monitoring-locations | **yes** |
| 385824077001901 | MO Fg  10 | 38.9734438009172 | -77.0049763735714 | Water Data API monitoring-locations | no (nearby only) |
| 385825077001701 | PG Cb   1 | 38.9737215744457 | -77.0044208082987 | Water Data API monitoring-locations | no (nearby only) |
| 385836077031501 | BEECH/OREGON, DC | 38.9766666666667 | -77.0530555555556 | Water Data API monitoring-locations | **yes** |
| 385841077023501 | RILEY SPRINGS, DC | 38.9783333333333 | -77.0425 | Water Data API monitoring-locations | **yes** |
| 385846077021601 | 16TH STREET, DC | 38.9794444444444 | -77.0369444444444 | Water Data API monitoring-locations | **yes** |
| 385901077030101 | DEERPRINT RUN, DC | 38.9816666666667 | -77.0508333333333 | Water Data API monitoring-locations | **yes** |
| 385903077024101 | WEST BEECH, DC | 38.9841666666667 | -77.0447222222222 | Water Data API monitoring-locations | **yes** |
| 385906077025801 | WEIR POND A, DC | 38.985 | -77.0491666666667 | Water Data API monitoring-locations | **yes** |
| 385907077024901 | PARKSIDE, DC | 38.9852777777778 | -77.0469444444444 | Water Data API monitoring-locations | **yes** |
| 01646500 | POTOMAC RIVER NEAR WASH, DC LITTLE FALLS PUMP STA | 38.94977778 | -77.12763889 | legacy site service (seed id) | no (nearby only) |

## NOAA CO-OPS water-level stations

- station list: ok; 302 station(s) returned

| station | name | lat | lon | found by | inside DC outline |
|---|---|---|---|---|---|
| 8594900 | Washington | 38.873333 | -77.02167 | CO-OPS station list (bbox) | **yes** |

## Limits

- USGS 15-minute data exist only from about October 2007 in the national archive; older events can only have daily values (if the gauge computes them).
- Gauge height and water-surface elevation are not rainfall: a gauge can stay flat during a short urban flood or react hours later.
- A missing record is not a water level of zero.
