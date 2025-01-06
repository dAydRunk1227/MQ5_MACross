//+------------------------------------------------------------------+
//|                                                      MACross.mq5 |
//|                                                         dAydrunk |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "dAydrunk"
#property version   "3.12"
/* 
  To-Do:
    - 1: - These symbols crash the test Error 4801(I think-dont remember when I wrote this) (not sure why this occurs. Looks like data is avaiable): EURGBP,GBPJPY,GBPUSD,USDJPY,EURUSD
    - 2: - Update running order SL to trail so it cant take out profits from ATR TP close. 
  VERSION HISTORY 
    - V3.12(24-0101) Update checkPosModify 
    - V3.11(24-0101) Update trade entry logic to enter at fast MA cross long MA or fast MA cross slow 
                        MA when both fast and slow MA are on the same side of the long MA and cross is in direction of that side
    - V3.1 (24-1228) Update modify positions to clean up Positions array and increase backtest speed.
    - V3   (24-1227) Add long MA for open trade check.
    - V2.6 (24-1110) Scrap current trailing stop method for single trade with partial close.
        - Add checkUpdatePosition();
        - Add PosPartialClose();  Add PosModify();
        - Add Trade input "iTrailingON" to allow running orders or enter trades with single TP and SL
        - Remove iAllowedTradesOnBar as it was deprecated sometime and has no purpose.
        - Update OrderBuy and OrderSell to accommodate JPY currency volumes
    - V2.5 (24-1102)
        -   Template EA
    - V2.41 (24-1102)
        - Reorganized formatting of declarations by category and then use
    - V2.4  (-------)
        - Added Trailing stop based on transaction event.  Two orders open simultaneously on open order signal.  One has set TP, one does not and is for "Running".
            When the order with the TP is closed, the running order's TP and SL are modified to increase the SL to prevent from losing gains, and a TP is added to auto close it. 
    - V2.33 (24-1019)
        - Update indicatorHandles() to print handle that failed to initialize
        - Limit number of allowed trades on the current bar.  Add input "iAllowedTradesOnBar" and function: checkNumOpenOrders() and checkNoOrdersDataCapture().  checkNumOpenOrders() is called by
             orderBuy and orderSell as check before order can be placed. checkNoOrdersDataCapture() is executed in orderBuy() and orderSell();
    - V2.32 (24-0908)
        - Implement To-Do item 2 (not started).
    - V2.31 (24-0908)
        - Implement To-Do item 2 (not started).
        - Add structure sDealsData 
        - Rename OrderHistoryDataFill() to TradeHistoryDataFill()
            - Add deals data fill functionallity  
    - V2.3 (24-0908)
        - Add scaling out function
            - Now opens two trades, each at half of full volume.  One closes at ATR based TP, the other closes at close signal only.  Both are closed by same SL
    - V2.22
        - Add OrderHistory metric output
            - structure sOrderData -- Variables/data write/Order Data
            - Array type sOrderData orderData[]  -- Variables/data write/Order Data
            - TradingHistoryDataFill(), populates order data to array of sOrderData -- Functions/Data Tracking
            - writeorderData(), writes order data to csv -- Functions/Data Tracking
            - TradingHistoryDataFill & writeorderData functions added to OnTester();
    - V2.21
        - Add Max Trade Profit, Max Loss Profit, and Expected Payoff stats to tester data output       
    - V2.2
        - Add file write properties to collect trade data from tester and order history information.
            - Add include: Trade\PositionInfo.mqh; SymbolInfoDouble.mqh; AccountInfo.mqh
            - Add class: COrInfo for easy access trade history values
            - Add Structure for Tester data store and write/print. See Variables/Data Write/Tester Statistics
            - Add OnTester() to get Strategy Tester Results and write to file. 
                - Note: Writes file located at C:\Users\redef\AppData\Roaming\MetaQuotes\Tester\EE0304F13905552AE0B5EAEFB04866EB\Agent-127.0.0.1-3000
            - Add "Data Tracking" Functions, located under "Functions"
        Open items:
        - (As of V2.1) See Variables/checkOpenPositions/Input - need to incorporate control for user determined
            allowable open positions.  Current is default only at 1 sell and/or buy at a time
    - V2.1
        - Modify close signal logic due to error in testing
        - document indicator data and function results for debugging with addtional of a reference string populated with info within/
            during functions calls to checkForSignalOpen and checkForSignalClose.  Values are printed in OnTick after each function call. 
        - Added debug statements to all debug print functions to limit data in log.
    - V2.0
        - Start new version that incorporates method for testing all symbols simultaneously.
    - V1.51
        - Move Update Signal methods from OnTick (not masterSignal) into functions setting signal.
    - V1.5
        - Begin Version changes logging
        - Migrate to Version AtBat1.5
        - Create Test3.0 to add Exit signal from MA indicators: 
            All MA signals equally create exit for signal's opposite
            Modify checkMA() to void function with MAsignalPassEn & MAsignalPassEx 
                parameters passed in by reference instead of returned
        - Deprecate MAsignalPass. Replace with MAsignalPassEn and MA signalPassEx
        - Deprecate bSignalsEn.  Replace with bSignalsEn[] & bSignalsEx[]
        - Deprecate updateSignals().  Replace with updateSignalsEn() & updateSignalsEx()
        - Add ETRADESIGNALS for position exit
        - Add updateSignalsEx(), which is duplicate of updateSignalsEn() modified respectively
        - Deprecate setmasterSignal().  Replace with setMasterSignalEn() & setMasterSignalEx()
        - Deprecate mMasterSignal. Replace with masterSignalEn & masterSignalEx
        - Add positionClose to handle MA exit signal and close positions
        - Add MA exit signal execution toggle user input 'iMAexitOn'
    */
// -- -- Include -- -- //
    #include <Trade\Trade.mqh>
    #include <Trade\PositionInfo.mqh>
    #include <Trade\SymbolInfo.mqh>
    #include <StdLibErr.mqh>
    ;

// -- -- DeBug -- -- //
   // #define dbgcheckMAOpen
   // #define dbgcheckMAClose
   // #define dbgmstrSigbSig
   // #define dbgmstrSig
   // #define dbgUpdateSignal
   // #define dbgPriceExit
   // #define dbgCheckOpen
   // #define volumeOrderSell
   // #define volumeOrderBuy
   // #define dbgCheckTimeRange
   // #define dbgMACD
   // #define dbgOpenSignal
   // #define dbgCloseSignal
    #define dbgTickCnt
   // #define dbgOpenOrder
   // #define dbgcheckNoOrders
   // #define dbgcheckUpdatePosition
        int dbgpositionArrayCount;
// -- -- Declarations -- -- //
    // -- -- Classes -- -- //
        CHistoryOrderInfo ChisOrInfo;       // Class Declaration.
        CTrade trade;                       // Class Declaration. Take advantae of existing trade tools. Used for to set expert magic number and open positions   
        CPositionInfo positionInfo;         // Class Declaration.
        CSymbolInfo symbolInfo;             // Class Declaration
    // -- -- Enums -- -- //
        // Trade
            enum ETRADESIGNAL   {
                    SIGNAL_NONE         =   0,  //  Trade signals, no trades
                    SIGNAL_BOTH         =   1,  //  Trade signals, Both directions received
                    SIGNAL_BUY          =   2,  //  Trade signals, Buy Signal received
                    SIGNAL_SELL         =   3,  //  Trade signals, Sell Signal received
                    SIGNAL_CLOSE_NONE   =   4,  //  Trade signals, no close signal
                    SIGNAL_CLOSE_BUY    =   5,  //  Trade signals, close open buy positions Signal received
                    SIGNAL_CLOSE_SELL   =   6,  //  Trade signals, close open sell positions Signal received
                    SIGNAL_ERROR        =   7,  //  Use where error in function inside of an type ETRADESIGNAL function
                    SIGNAL_POSOPEN_NONE =   8,  //  Use for Positiong open check, no positions open. Help simplify troubleshooting.
                    SIGNAL_POSOPEN_BUY  =   9,  //  Use for Positiong open check, buy poitions open. Help simplify troubleshooting.
                    SIGNAL_POSOPEN_SELL =   10, //  Use for Positiong open check, sell poitions open. Help simplify troubleshooting.
                    SIGNAL_POSOPEN_BOTH =   11, //  Use for Positiong open check, buy & sell poitions open. Help simplify troubleshooting.
                };
    // -- -- Structures -- -- //
        // Order Data Log
            struct sOrdersData {                   // Data associated with Orders
               
                datetime            timeSetup;    // Order setup time  
                datetime            timeDone;     // Order execution or cancellation time
                double              priceO;       // Price specified in the order
                double              priceC;       // The current price of the order symbol
                double              volumeI;      // Order initial volume
                double              SL;           // Stop Loss value
                double              TP;           // Take Profit value
                ENUM_ORDER_TYPE     type;         // Order type 0=buy, 1=sell
                long                orderMagic;   // ID of an Expert Advisor that has placed the order (designed to ensure that each Expert Advisor places its own unique number)
                long                positionID;   // Position identifier that is set to an order as soon as it is executed. Each executed order results in a deal that opens or modifies an already existing position. The identifier of exactly this position is set to the executed order at this moment.
                string              sym;          // Symbol of the order
                string              comment;      // Order comment
                ulong               ticket;       // Order ticket. Unique number assigned to each order  
                };  
               
            struct sDealsData {                    // Data associated with Deals
                double              volumeDl;       // Deal volume
                double              priceDl;        // Deal price
                double              profitDl;       // Deal profit
                datetime            timeDeal;       // Deal time
                ENUM_DEAL_TYPE      typeDl;         // Deal type
                long                dealMagic;      // Deal magic number (see ORDER_MAGIC)
                long                orderNoDl;      // Deal order number
                long                positionIDDl;   // Identifier of a position, in the opening, modification or closing of which this deal took part. Each position has a unique identifier that is assigned to all deals executed for the symbol during the entire lifetime of the position.
                ulong               ticketDl;       // Deal ticket. Unique number assigned to each deal
                string              commentDl;      // Deal comment
                string              symDl;          // Deal symbol
                };
        // Tester Statistics **There are a lot I haven't added yet**
            struct sTestStats {             // Declare Structure
                    double  initDep;            // The value of the initial deposit
                    double  profit;             // Net profit after testing, the sum of STAT_GROSS_PROFIT and STAT_GROSS_LOSS (STAT_GROSS_LOSS is always less than or equal to zero)
                    double  grProfit;           // Total profit, the sum of all profitable (positive) trades. The value is greater than or equal to zero
                    double  grLoss;             // Total loss, the sum of all negative trades. The value is less than or equal to zero
                    double  maxProfitTrd;       // Maximum profit – the largest value of all profitable trades. The value is greater than or equal to zero
                    double  maxLossTrade;       // Maximum loss – the lowest value of all losing trades. The value is less than or equal to zero
                    double  profitFact;         // Profit factor, equal to  the ratio of STAT_GROSS_PROFIT/STAT_GROSS_LOSS. If STAT_GROSS_LOSS=0, the profit factor is equal to DBL_MAX
                    double  dealCnt;            // The number of deals
                    double  tradeCnt;           // The number of trades
                    double  tradesWin;          // Profitable trades
                    double  tradesLoss;         // Losing trades
                    double  tradesShort;        // Short trades
                    double  tradesLong;         // Long trades
                    double  tradesShtProfit;    // Profitable short trades
                    double  tradesLgProfit;     // Profitable long trades
                    double  avgTradesSerPro;    // Average length of a profitable series of trades
                    double  avgTradesSerLos;    // Average length of a losing series of trades
                    double  expectedPayoff;     // Expected payoff
                    };
            sTestStats StestStats;
        // Position Info
            struct sPos {
                double      tp;
                int         symbolLoop;
                long        posID;
                datetime    lastPosUpdate;
                bool        isTrailing;          // flag to control tp updating after partial position close
                };

    // -- -- Arrays -- -- //
        // All symbols
            ulong    OpenTradeOrderTicket[];    //To store 'order' ticket for trades
            string   SymbolArray[];             // Stores list of symbols in an array of strings. Used to assist in processing
        // Indicator Handles
            int handle_MAFast[];    // Moving Average Fast, Stores handles for all symbols to use
            int handle_MASlow[];    // Moving Average Slow, Stores handles for all symbols to use
            int handle_MALong[];    // Moving Average Long, Stores handles for all symbols to use
            int handle_ATR[];       // Stores ATR handle for All Symbols  
            // int handle_MACD[];  // Stores MACD handle for All Symbols
        // Order & Positions Data
            sOrdersData ordersData[];              // Array to store sOrderData structure for write to file
            sDealsData  dealsData[];               // Array to store sDealData structure for write to file
            sPos        bsPos[];                   // Array to store order info for checking if orders need update
    // -- -- Variables -- -- //
        // -- -- Common Variables -- -- //
            input int   iMagic;                 //  Magic Number
            int         TicksReceivedCount = 0; //  Track tick number to assist in debugging.  See first line of OnTick and update in orderBuy() and orderSell().     
        // -- -- Trade Variables -- -- //
            // Inputs
                input group "Trade"
                input bool      iTrailingON = false; //  Toggle trailing stop On/Off    
                input double    iMaxOrder   = 2;     //  Max % of account value allowed
                input int       iVolFactor  = 1;     //  Min 1 max 10
            // Working
                string tradeCommentBuy1  =  "OrderSend";        //  Sets buy trade comment to distinguish cale out
                string tradeCommentBuy2  =  "Buy, Running";     //  Sets buy trade comment to distinguish runner
                string tradeCommentSell1 =  "OrderSend";       //  Sets sell trade comment to distinguish cale out
                string tradeCommentSell2 =  "Sell, Running";    //  Sets sell trade comment to distinguish runner
                
                double volumeBuyPass;   //  used to store calculated buy trade volume for order place
                double volumeSellPass;  //  used to store calculated buy trade volume for order place
        // -- -- All Symbols Variables -- -- //
            // Inputs
            input string TradeSymbols   =   "AUDNZD|USDCHF|AUDCAD|AUDUSD|EURUSD";  //  Can manually type Symbol(s) in here or type "ALL" or "CURRENT"            
            
            //Variables 
            string   AllSymbolsString           = "AUDCAD|EURAUD|EURCAD|EURNZD|AUDNZD|EURJPY|GBPCAD|GBPNZD|NZDCAD|NZDJPY|NZDUSD|USDCAD|GBPAUD|CADJPY|USDCHF"; 
            int      NumberOfTradeableSymbols;               
        // -- -- Indicators Varibles -- -- //
            //  ATR -- StopLoss & TakeProfit
                // Inputs
                input group "ATR Parameters"
                input double            iTPmultiplier   = 2.5;  // Multiplier for TP
                input double            iSLmultiplier   = 1;    // Multiplier for SL 
                input ENUM_TIMEFRAMES   iATRtf          = 0;    // ATR Timeframe (0=current chart)
                input int               iATRperiod      = 14;   // ATR Calculated Period   
            
                // Working   
                double bTP;       // Stores buy TakeProfit calculated from ask and Modified ATR value. Use for TP argument in order function.
                double bSL;       // Stores buy StopLoss calculated from ask and Modified ATR value. Use for SL argument in order function.
                double sTP;       // Stores sell TakeProfit calculated from bid and Modified ATR value. Use for TP argument in order function.
                double iTP;       // Suspect memory allocates too many values to the multipler (ex. input = 0.2, variable is 0.200000000011). Limiting number of digits by normlizing the input and storing it in this.
                double iSL;       // Suspect memory allocates too many values to the multipler (ex. input = 0.2, variable is 0.200000000011). Limiting number of digits by normlizing the input and storing it in this.
                double sSL;       // Stores sell StopLoss calculated from bid and Modified ATR value. Use for SL argument in order function.
            
            //  Moving Average 
                // Inputs
                input group "Moving Average Parameters"
                input bool                  iMAexitOn       =   true;            //  Toggle use of MA exit signal
                input ENUM_TIMEFRAMES       iMATF           =   PERIOD_CURRENT;  //  MA Timeframe
                input ENUM_APPLIED_PRICE    iMAApplPrc      =   PRICE_CLOSE;     //  MA Price  
                input ENUM_MA_METHOD        iMAMethodFast   =   MODE_SMA;        //  Fast MA Method
                input int                   iMAFastPrd      =   10;              //  MA Fast Period
                input int                   iMAFastSft      =   0;               //  MA Fast Shift
                input ENUM_MA_METHOD        iMAMethodSlow   =   MODE_SMA;        //  Slow MA Method
                input int                   iMASlowPrd      =   20;              //  MA Slow Period
                input int                   iMASlowSft      =   0;               //  MA Slow Shift      
                input ENUM_MA_METHOD        iMAMethodLong   =   MODE_SMA;        //  Long MA Method
                input int                   iMALongPrd      =   20;              //  MA Long Period
                input int                   iMALongSft      =   0;               //  MA Long Shift      
      
            /*//  Adaptive Moving Average
                //Inputs
                input group "Adaptive Moving Average Parameters"
                input ENUM_TIMEFRAMES       iAMATF          =   PERIOD_CURRENT;  //  AMA Timeframe
                input ENUM_APPLIED_PRICE    iAMAApplPrc     =   PRICE_CLOSE;     //  Slow AMA Method
                input int                   iAMAPrd         =   5;               //  AMA Period
                input int                   iAMAShift       =   0;               //  AMA Shift
                input int                   iAMA        =   5;               //  AMA Fast
                input int                   iAMASlow        =   5;               //  AMA Slow              */                    
            /*//  MACD
                // Inputs
                    input group "MACD Parameters"
                    input bool                  MACDonOff       =   true;               //  MACD Signal Is Used
                    input ENUM_TIMEFRAMES       iMACDPeriod     =   PERIOD_CURRENT;     //  MACD Timeframe
                    input int                   iMACDFastPrd    =   12;                 //  MACD Fast Period
                    input int                   iMACDSlowPrd    =   26;                 //  MACD Slow Period
                    input int                   iMACDDiffPrd    =   12;                 //  Diff Period
                    input ENUM_APPLIED_PRICE    iMACDApplPrc    =   PRICE_CLOSE;    //  Applied Calculation Price                    
                // Working
                    double bMACD[];  //  MACD Data Buffer

                    ETRADESIGNAL MACDsignalPass;  // MACD result
    
                    int hMACD;          //  MACD Handle*/
            

        // -- -- Signal Variables -- -- //
            // Inputs -- for CheckTimeRange
                input group "Time Range"    // Use to set desired time range to trade in
                input int startHr   = 25;          // TimeRange start hour
                input int startMn   = 00;          // TimeRange start min
                input int endHr     = 25;          // TimeRange end hour
                input int endMn     = 00;          // TimeRange end min
            // Working
                    ETRADESIGNAL posOpnSglPs;   // use with checkOpenPositions to pass result to signal array
                    ETRADESIGNAL chkTRPass;     // us with checkTimeRange to pass result
        
        // -- -- Data Logging Variables -- -- 
            // Write
                string filename  = "TestWrite.csv";
                string filename1 = "PosArray.csv";
                int filehandle;
// -- -- Expert Init -- -- //
    int OnInit() {
        trade.SetExpertMagicNumber(iMagic);     //  Set EA magic number
        
        //  Set-Up All Symbols
            // SET UP ANY VARIABLES
                iTP  =   NormalizeDouble(iTPmultiplier, 2);
                iSL  =   NormalizeDouble(iSLmultiplier, 2);
            // DEFINE SYMBOLS FOR USE
                if(TradeSymbols == "CURRENT")   {  // Override TradeSymbols input variable and use the current chart symbol only
                    NumberOfTradeableSymbols = 1;
                    ArrayResize(SymbolArray, 1);
                    SymbolArray[0] = Symbol(); 
                    Print("EA will process ", SymbolArray[0], " only");
                    }
                    else { string TradeSymbolsToUse = "";
                        if(TradeSymbols == "ALL")
                            TradeSymbolsToUse = AllSymbolsString;
                        else
                            TradeSymbolsToUse = TradeSymbols;
                        NumberOfTradeableSymbols = StringSplit(TradeSymbolsToUse, '|', SymbolArray); // CONVERT TradeSymbolsToUse TO THE STRING ARRAY SymbolArray
                        Print("EA will process: ", NumberOfTradeableSymbols, " ", TradeSymbolsToUse);
                        }
            // RESIZE OPEN TRADE ARRAYS (based on how many symbols are being traded)
                ResizeCoreArrays();
            // RESIZE INDICATOR HANDLE ARRAYS
                ResizeIndicatorHandleArrays();
                
                Print("All arrays sized to accomodate ", NumberOfTradeableSymbols, " symbols");
            // INITIALIZE ARRAYS
                for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
                    OpenTradeOrderTicket[SymbolLoop] = 0;
            // INSTANTIATE INDICATOR HANDLES
                if(!SetUpIndicatorHandles())
                    return(INIT_FAILED); 
                
                return(INIT_SUCCEEDED);   
        }
// -- -- Expert tick function -- -- //
    void OnTick()   {

        TicksReceivedCount++;
        #ifdef dbgTickCnt Comment(TicksReceivedCount);
            int tick = 45705;
            if( tick != 0 && TicksReceivedCount == tick ) DebugBreak(); #endif
        string indicatorMetrics = "";
      

      //LOOP THROUGH EACH SYMBOL TO CHECK FOR ENTRIES AND EXITS, AND THEN OPEN/CLOSE TRADES AS APPROPRIATE
        for(int SymbolLoop = 0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)  {
            string CurrentIndicatorValues; //passed by ref below
            
            // Update Positions
                checkUpdatePosition(SymbolLoop, CurrentIndicatorValues);
            
            // Get Close Signal 
                ETRADESIGNAL CloseSignalStatus = checkForCloseSignal(SymbolLoop, CurrentIndicatorValues);
                #ifdef dbgCloseSignal Print(CurrentIndicatorValues, " clSigChk: %d", CloseSignalStatus, "\nSym: ", SymbolArray[SymbolLoop]); #endif
            
            // Process Trade Closeures
                if(CloseSignalStatus == SIGNAL_CLOSE_SELL || CloseSignalStatus == SIGNAL_CLOSE_BUY) {
                    ProcessTradeClose(SymbolLoop, CloseSignalStatus);
                    #ifdef dbgCloseSignal if(CloseSignalStatus !=0) { PrintFormat("Func: %s, SymLoop: %d, ClSigStat: %d", __FUNCSIG__, 
                                                                    SymbolLoop, CloseSignalStatus); } #endif
                        }
            
            // Check Open Signal (MA Cross)
                ETRADESIGNAL OpenSignalStatus = checkForOpenSignal(SymbolLoop, CurrentIndicatorValues);      
                #ifdef dbgOpenSignal Print(CurrentIndicatorValues, " opnSigChk: %d, ", OpenSignalStatus, "\nSym: ", SymbolArray[SymbolLoop]); #endif
            
            // Process Trade open
                if(OpenSignalStatus == SIGNAL_BUY || OpenSignalStatus == SIGNAL_SELL) {
                    ProcessTradeOpen(SymbolLoop, OpenSignalStatus);         
                    #ifdef dbgOpenSignal PrintFormat("Fun: %s, OpSigStat: %d", __FUNCSIG__, OpenSignalStatus); #endif
                    positionArrayMaintenance();
                    }
            
            }
        }
        
// -- -- OnEvent -- -- //
    void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) {
        Print("TradeTrans Tick: ", TicksReceivedCount);
        }
// -- -- OnTester -- -- //
    double OnTester() {
        double ret = 1;
        writeTestStats();
        Print("OnTester Stats 1 Successful");
        writeorderData();
        Print("OnTester Stats 2 Successful");
        return(ret);
        }
// -- -- Expert deinitialization function -- -- //
    void OnDeinit(const int reason) {   // *** Are these used???? 
        for(int SymbolLoop = 0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)  {
            IndicatorRelease(handle_ATR[SymbolLoop]);
            IndicatorRelease(handle_MAFast[SymbolLoop]);
            IndicatorRelease(handle_MASlow[SymbolLoop]);
            IndicatorRelease(handle_MALong[SymbolLoop]);
            
            //IndicatorRelease(handle_AMA[SymbolLoop]);
            }    
        Print("\n\rMulti-Symbol EA Stopped");
        }
// -- -- Functions -- -- //  Potentially future include files: working functions below here
    // -- -- All Symbols Specific Functionality
        bool SetUpIndicatorHandles()  {                  
            for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)  {
                ResetLastError();   //Reset any previous error codes so that only gets set if problem setting up indicator handle
            
                handle_MAFast[SymbolLoop]   = iMA( SymbolArray[SymbolLoop], iMATF, iMAFastPrd, iMAFastSft, iMAMethodFast, iMAApplPrc);
                handle_MASlow[SymbolLoop]   = iMA( SymbolArray[SymbolLoop], iMATF, iMASlowPrd, iMASlowSft, iMAMethodSlow, iMAApplPrc);
                handle_MALong[SymbolLoop]   = iMA( SymbolArray[SymbolLoop], iMATF, iMALongPrd, iMALongSft, iMAMethodLong, iMAApplPrc);
                handle_ATR[SymbolLoop]      = iATR(SymbolArray[SymbolLoop], iATRtf, iATRperiod);

                if(handle_MAFast[SymbolLoop] == INVALID_HANDLE || handle_MASlow[SymbolLoop] == INVALID_HANDLE || handle_ATR[SymbolLoop] == INVALID_HANDLE 
                    || handle_MALong[SymbolLoop] == INVALID_HANDLE) { 
                    string outputMessage    = "";
                    string outputMessage1   = "";
                    if(GetLastError() == 4302)  outputMessage = "Symbol needs to be added to the MarketWatch";
                        else
                            StringConcatenate(outputMessage, "(error code ", GetLastError(), ")", "tick: ", TicksReceivedCount);
                            if( handle_MAFast[SymbolLoop] == INVALID_HANDLE )           {outputMessage1 = "MAFast";}
                                else if( handle_MASlow[SymbolLoop] == INVALID_HANDLE )  {outputMessage1 = "MASlow";}
                                else if( handle_ATR[SymbolLoop] == INVALID_HANDLE )     {outputMessage1 = "ATR";}

                            Print("Failed to create handle for the ", outputMessage1, " indicator for " + SymbolArray[SymbolLoop] + "/" + EnumToString(Period()) + "\n\r\n\r" + 
                                        outputMessage +
                                        "\n\r\n\rEA will now terminate.");           
                            
                            return false;   //Don't proceed
                    }
                
                Print("Handle for:  ", SymbolArray[SymbolLoop], " / ", EnumToString(Period()), " successfully created");
                }
            return true;    // All completed without errors, return true
            }
    
        bool custCopyBuffer(int ind_handle,            // handle of the indicator 
                            int buffer_num,            // for indicators with multiple buffers
                            double &localArray[],      // local array 
                            int numBarsRequired,       // number of values to copy 
                            string symbolDescription,  
                            string indDesc)  {
      
            int availableBars;
            bool success = false;
            int failureCount = 0;
            
            //Sometimes a delay in prices coming through can cause failure, so allow 3 attempts
            while(!success) {
                
                availableBars = BarsCalculated(ind_handle);

                if(availableBars < numBarsRequired) {
                    failureCount++;
                    
                    if(failureCount >= 3)   {
                        Print("Failed to calculate sufficient bars in custCopyBuffer() after ", failureCount, " attempts (", symbolDescription, "/", indDesc, " - Required=", numBarsRequired, " Available=", availableBars, ")");
                        return(false);
                        }
                    
                    Print("Attempt ", failureCount, ": Insufficient bars calculated for ", symbolDescription, "/", indDesc, "(Required=", numBarsRequired, " Available=", availableBars, ")");
                    
                    //Sleep for 0.1s to allow time for price data to become usable
                    Sleep(100);
                    }
                else    {
                    success = true;
                    
                    if(failureCount > 0) //only write success message if previous failures registered
                    Print("Succeeded on attempt ", failureCount+1);
                    }
                }
            
            ResetLastError(); 
            
            int numAvailableBars = CopyBuffer(ind_handle, buffer_num, 0, numBarsRequired, localArray);
            
            if(numAvailableBars != numBarsRequired) { 
                Print("Failed to copy data from indicator with error code ", GetLastError(), ". Bars required = ", numBarsRequired, " but bars copied = ", numAvailableBars, "tick: ", TicksReceivedCount);
                return(false); 
                } 
            
            //Ensure that elements indexed like in a timeseries (with index 0 being the current, 1 being one bar back in time etc.)
            ArraySetAsSeries(localArray, true);
            
            return(true); 
            }
        void ResizeCoreArrays() {
            ArrayResize(OpenTradeOrderTicket, NumberOfTradeableSymbols);
            ArrayResize(bsPos, 0);
            // Add other trade arrays here as needed
            }
        void ResizeIndicatorHandleArrays()  {
            ArrayResize(handle_ATR, NumberOfTradeableSymbols);
            ArrayResize(handle_MAFast, NumberOfTradeableSymbols);
            ArrayResize(handle_MASlow, NumberOfTradeableSymbols);
            ArrayResize(handle_MALong, NumberOfTradeableSymbols);
            // Add other indicator handes here as needed
            
            //ArrayResize(handle_AMA, NumberOfTradeableSymbols);
            //ArrayResize(handle_MACD, NumberOfTradeableSymbols);
            }
    // -- -- Data Tracking
        void fillTesterStats(sTestStats &stats) {
             stats.initDep          =   TesterStatistics(STAT_INITIAL_DEPOSIT);
             stats.profit           =   NormalizeDouble(TesterStatistics(STAT_PROFIT),2);
             stats.grProfit         =   NormalizeDouble(TesterStatistics(STAT_GROSS_PROFIT),2);
             stats.grLoss           =   NormalizeDouble(TesterStatistics(STAT_GROSS_LOSS),2);
             stats.maxProfitTrd     =   NormalizeDouble(TesterStatistics(STAT_MAX_PROFITTRADE),2);      
             stats.maxLossTrade     =   NormalizeDouble(TesterStatistics(STAT_MAX_LOSSTRADE),2);     
             stats.profitFact       =   NormalizeDouble(TesterStatistics(STAT_PROFIT_FACTOR),2);
             stats.dealCnt          =   (int)TesterStatistics(STAT_DEALS);
             stats.tradeCnt         =   (int)TesterStatistics(STAT_TRADES);
             stats.tradesWin        =   (int)TesterStatistics(STAT_PROFIT_TRADES);
             stats.tradesLoss       =   (int)TesterStatistics(STAT_LOSS_TRADES);
             stats.tradesShort      =   (int)TesterStatistics(STAT_SHORT_TRADES);
             stats.tradesLong       =   (int)TesterStatistics(STAT_LONG_TRADES);
             stats.tradesShtProfit  =   (int)TesterStatistics(STAT_PROFIT_SHORTTRADES);
             stats.tradesLgProfit   =   (int)TesterStatistics(STAT_PROFIT_LONGTRADES);
             stats.avgTradesSerPro  =   (int)TesterStatistics(STAT_PROFITTRADES_AVGCON);
             stats.avgTradesSerLos  =   (int)TesterStatistics(STAT_LOSSTRADES_AVGCON);
             stats.expectedPayoff   =   (int)TesterStatistics(STAT_EXPECTED_PAYOFF);   
            }
        void writeTestStats()   {
            fillTesterStats(StestStats);                             // Fills Tester Stats Structure Values
            filehandle = FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV);
            if(filehandle != INVALID_HANDLE ) {
                FileWrite(filehandle, "InitialDeposit", "Profit", "GrossProfit", "GrossLoss", "MaxProfitTrade", "MaxLossTrade", "ExpectedPayOff", "ProfitFactor", "Deals", "Trades", "TradesWin",
                                      "TradesLoss", "ShortTrades", "LongTrades", "ProfitShortTrades", "ProfitLongTrades", "LengthProfitTradeSeries", "LengthLossTradeSeries", "PosArraySize"); 
                FileWrite(filehandle, StestStats.initDep, StestStats.profit, StestStats.grProfit, StestStats.grLoss, StestStats.maxProfitTrd,  StestStats.maxLossTrade, StestStats.expectedPayoff, 
                                      StestStats.profitFact, StestStats.dealCnt, StestStats.tradeCnt, StestStats.tradesWin, StestStats.tradesLoss, StestStats.tradesShort, StestStats.tradesLong, 
                                      StestStats.tradesShtProfit, StestStats.tradesLgProfit, StestStats.avgTradesSerPro, StestStats.avgTradesSerLos, dbgpositionArrayCount);                

                        Print("File Written Successfully");
                        FileClose(filehandle);
                }
            else { Print("File FAILED to open"); }
            }
        void TradingHistoryDataFill() {
           
            bool select = HistorySelect(0, TimeCurrent());
            int  ordersTotal = HistoryOrdersTotal(); // Get the total number of historical orders
            int  dealsTotal  = HistoryDealsTotal();

            ArrayResize(ordersData, ordersTotal);
            ArrayResize(dealsData, dealsTotal);   
            
            // Get the ticket of the order at the given index
            for(int i = 0; i < ordersTotal; i++) {      
               
                ulong mTicket;                   
                // Now select the order by its ticket
                if((mTicket = HistoryOrderGetTicket(i))>0) {         
                    sOrdersData order;
                    order.ticket        = mTicket;
                    order.sym           = HistoryOrderGetString(mTicket, ORDER_SYMBOL);
                    order.comment       = HistoryOrderGetString(mTicket, ORDER_COMMENT);
                    order.priceC        = NormalizeDouble(HistoryOrderGetDouble(mTicket, ORDER_PRICE_CURRENT), _Digits);
                    order.priceO        = NormalizeDouble(HistoryOrderGetDouble(mTicket, ORDER_PRICE_OPEN),_Digits);
                    order.volumeI       = NormalizeDouble(HistoryOrderGetDouble(mTicket, ORDER_VOLUME_INITIAL), 2);          
                    order.SL            = NormalizeDouble(HistoryOrderGetDouble(mTicket, ORDER_SL),_Digits);          
                    order.TP            = NormalizeDouble(HistoryOrderGetDouble(mTicket, ORDER_TP),_Digits);          
                    order.type          = (ENUM_ORDER_TYPE)(HistoryOrderGetInteger(mTicket, ORDER_TYPE));
                    order.timeSetup     = (datetime)HistoryOrderGetInteger(mTicket, ORDER_TIME_SETUP);
                    order.timeDone      = (datetime)HistoryOrderGetInteger(mTicket, ORDER_TIME_DONE);
                    order.orderMagic   = HistoryOrderGetInteger(mTicket, ORDER_MAGIC);
                    order.positionID    = HistoryOrderGetInteger(mTicket, ORDER_POSITION_ID);                    

                    ordersData[i] = order;
                    }
                }
            
            // Get the ticket of the deal at the given index
            for(int i = 0; i < dealsTotal; i++) {      
                ulong mTicket;                   
                // Now select the deal by its ticket
                if((mTicket = HistoryOrderGetTicket(i))>0) {         
                    sDealsData deals;
                    deals.ticketDl      = mTicket;
                    deals.orderNoDl     = HistoryDealGetInteger(mTicket, DEAL_ORDER);
                    deals.commentDl     = HistoryDealGetString(mTicket, DEAL_COMMENT);
                    deals.priceDl       = NormalizeDouble(HistoryDealGetDouble(mTicket, DEAL_PRICE), _Digits);
                    deals.profitDl      = NormalizeDouble(HistoryDealGetDouble(mTicket, DEAL_PROFIT),_Digits);
                    deals.volumeDl      = NormalizeDouble(HistoryDealGetDouble(mTicket, DEAL_VOLUME), 2);          
                    deals.typeDl        = (ENUM_DEAL_TYPE)(HistoryOrderGetInteger(mTicket, ORDER_TYPE));
                    deals.timeDeal      = (datetime)HistoryDealGetInteger(mTicket, DEAL_TIME);
                    deals.dealMagic    = HistoryDealGetInteger(mTicket, DEAL_MAGIC);
                    deals.positionIDDl  = HistoryDealGetInteger(mTicket, DEAL_POSITION_ID);                    
                    deals.symDl         = HistoryDealGetString(mTicket, DEAL_SYMBOL);
                    
                    dealsData[i] = deals;
                    }
                    }
                }
        void writeorderData() {
            TradingHistoryDataFill();
           
            int index = 0;

            filehandle = FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV);
            FileSeek(filehandle, 0, SEEK_END);
            
            if(filehandle != INVALID_HANDLE ) {
                FileWrite(filehandle, "\nTypes:", "0=buy", "1=sell\n");
                FileWrite(filehandle, "Symbol", "Dl.OrderType", "Dl.Volume (Lots)", "Ord.FillPrice", "Dl.Price", "Dl.Profit", "Ord.StopLoss", "Ord.TakeProfit", "Dl.Time", 
                                      "Ord.MagicNo", "Ord.TradeComment",  "Ord.Ticket", "Dl.Ticket", "Ord.PosID", "Dl.PosID", "Dl.OrderNo", "TestNo.");
                for(int i=0; i<=ArraySize(ordersData); i++) { if( i>=0 && i<HistoryOrdersTotal() && i<HistoryDealsTotal()) { index = i;
                    FileWrite(filehandle, ordersData[i].sym, dealsData[i].typeDl, dealsData[i].volumeDl, ordersData[i].priceC, dealsData[i].priceDl, dealsData[i].profitDl, ordersData[i].SL, 
                                          ordersData[i].TP, dealsData[i].timeDeal, dealsData[i].dealMagic, dealsData[i].commentDl,  ordersData[i].ticket, dealsData[i].ticketDl, 
                                          ordersData[i].positionID, dealsData[i].positionIDDl, dealsData[i].orderNoDl); }
                    }
                Print("Stats File Written Successfully");
                FileClose(filehandle);
                }
                else { Print("File FAILED to open: ", index); }    
            }

    // -- -- Position Control -- -- //
        void ProcessTradeOpen(int SymbolLoop, ETRADESIGNAL TradeDirection)  {
            string CurrentSymbol = SymbolArray[SymbolLoop];
            if (TradeDirection == SIGNAL_NONE) {return;}
            else if (TradeDirection == SIGNAL_BUY)  { orderVolumeBuy(iVolFactor, iMaxOrder, CurrentSymbol);     
                                                      bool TPSLcheck = createTPSL(iTP, iSL, TradeDirection, CurrentSymbol, SymbolLoop); 
                                                      if(TPSLcheck == true) { orderBuy(bTP, bSL, volumeBuyPass, CurrentSymbol); }
                                                        else Print("processTradeOpen Buy Fail due to TPSL fail", " Error: ", GetLastError(), "Tick: ", TicksReceivedCount);
                                                        return;
                                                        }
            else if (TradeDirection == SIGNAL_SELL) { orderVolumeSell(iVolFactor, iMaxOrder, CurrentSymbol); 
                                                      bool TPSLcheck = createTPSL(iTP, iSL, TradeDirection, CurrentSymbol, SymbolLoop);
                                                      if(TPSLcheck == true) { orderSell(sTP, sSL, volumeSellPass, CurrentSymbol); }
                                                      else Print("processTradeOpen Sell Fail due to TPSL fail", " Error: ", GetLastError(), "Tick: ", TicksReceivedCount );
                                                        return;
                                                        }
            }
        void ProcessTradeClose(int SymbolLoop, ETRADESIGNAL TradeDirection) {
            string CurrentSymbol = SymbolArray[SymbolLoop];
            bool closeCheck;

            if(iMAexitOn != true ) { return; }  
            
            int Cnt = PositionsTotal();
            int i = Cnt-1;
                
            for(i; i >= 0; i--) {                         
                    
                ulong tx = PositionGetTicket(i); 
                bool postx = PositionSelectByTicket(tx);
                closeCheck = false;

                if(Cnt<1) { return; }      
                if(!postx) {
                    Print("Ticket select fail: ", GetLastError(), " for tx: ", tx, "Tick: ", TicksReceivedCount); continue;
                    }
                 if(TradeDirection == SIGNAL_CLOSE_BUY &&                              
                        PositionGetInteger(POSITION_MAGIC)  == iMagic &&  
                        PositionGetInteger(POSITION_TYPE)   == POSITION_TYPE_BUY &&
                        PositionGetString(POSITION_SYMBOL)  == CurrentSymbol ) { 
                            
                            closeCheck = trade.PositionClose(tx, ULONG_MAX); 
                            
                            if (!closeCheck) { Print("Failed to close: ", tx, " Error: ", GetLastError(), "Tick: ", TicksReceivedCount ); }
                            }

                 if(TradeDirection == SIGNAL_CLOSE_SELL &&                           
                        PositionGetInteger(POSITION_MAGIC)  == iMagic &&                              
                        PositionGetInteger(POSITION_TYPE)   == POSITION_TYPE_SELL &&
                        PositionGetString(POSITION_SYMBOL)  == CurrentSymbol ) { 
                            
                            closeCheck = trade.PositionClose(tx, ULONG_MAX); 
                            
                            if (!closeCheck) { Print("Failed to close: ", tx, " Error: ", GetLastError(), "Tick: ", TicksReceivedCount ); }
                            }
                }
            }
                   
        void orderBuy(double tp, double sl, double vol, string Symbol) {               //  See void placeOrder()
            
            double mBid     =   SymbolInfoDouble(Symbol, SYMBOL_BID);
            double mVol     =   NormalizeDouble((vol), 2);
            
            #ifdef dbgOpenOrder DebugBreak(); #endif

            if( iTrailingON == false ) { trade.PositionOpen(Symbol, ORDER_TYPE_BUY, mVol, mBid, sl, tp, tradeCommentBuy1); }
            
            else if( trade.PositionOpen(Symbol, ORDER_TYPE_BUY, mVol, mBid, sl, NULL, tradeCommentBuy1) ) { 
                // Find the most recent position for this symbol
                long        newestTicket    = -1;
                datetime    latestTime      = 0;
                datetime    openTime        = 0;

                for ( int i = PositionsTotal() - 1; i >= 0; i-- ) {  // Iterate over all positions
                    if  (positionInfo.SelectByIndex(i) ) {           // Select each position
                        if ( positionInfo.Symbol() == Symbol ) {     // Match the symbol
                            openTime = positionInfo.Time();
                            if ( openTime > latestTime ) {           // Check for the latest open time
                                latestTime = openTime;
                                newestTicket = PositionGetInteger(POSITION_TICKET);
                                #ifdef dbgOpenOrder PrintFormat( "orderSell info || Sym: %s, PosOpentime: s%, latestTime: %s, Ticket: %g tickCnt: %g", Symbol, TimeToString(openTime), TimeToString(latestTime), newestTicket, TicksReceivedCount ); #endif
                                }
                            }
                        }
                    }

                if (newestTicket != -1) { 
                    // Successfully found the newest position
                    int i = ArrayResize(bsPos, ArraySize(bsPos) + 1) - 1;
                    sPos x;
                    x.posID = newestTicket;
                    x.tp = tp;
                    x.lastPosUpdate = openTime;
                    x.isTrailing = false;
                    bsPos[i] = x;

                    #ifdef dbgOpenOrder ArrayPrint(bsPos[i]); #endif
                    } 
                    
                    else { Print("Error: Could not find the newest position for symbol: ", Symbol); }
                } 
                else { Print("orderSell Fail", " Error: ", GetLastError(), "Tick: ", TicksReceivedCount); }
            }

        void orderSell(double tp, double sl, double vol, string Symbol) {             
            
            double mAsk = SymbolInfoDouble(Symbol, SYMBOL_ASK);
            double mVol = NormalizeDouble(vol, 2);

            #ifdef dbgOpenOrder DebugBreak(); #endif

            if( iTrailingON == false ) { trade.PositionOpen(Symbol, ORDER_TYPE_SELL, mVol, mAsk, sl, tp, tradeCommentSell1); }
            
            else if ( trade.PositionOpen(Symbol, ORDER_TYPE_SELL, mVol, mAsk, sl, NULL, tradeCommentSell1) ) { 
                // Find the most recent position for this symbol
                long        newestTicket    = -1;
                datetime    latestTime      = 0;
                datetime    openTime        = 0;

                for ( int i = PositionsTotal() - 1; i >= 0; i-- ) {  // Iterate over all positions
                    if  (positionInfo.SelectByIndex(i) ) {           // Select each position
                        if ( positionInfo.Symbol() == Symbol ) {     // Match the symbol
                            openTime = positionInfo.Time();
                            if ( openTime > latestTime ) {           // Check for the latest open time
                                latestTime = openTime;
                                newestTicket = PositionGetInteger(POSITION_TICKET);
                                #ifdef dbgOpenOrder PrintFormat( "orderSell info || Sym: %s, PosOpentime: s%, latestTime: %s, Ticket: %g, TickCount: %g", Symbol, TimeToString(openTime), TimeToString(latestTime), newestTicket, TicksReceivedCount ); #endif
                                }
                            }
                        }
                    }

                if (newestTicket != -1) { 
                    // Successfully found the newest position
                    int i = ArrayResize(bsPos, ArraySize(bsPos) + 1) - 1;
                    sPos x;
                    x.posID         = newestTicket;
                    x.tp            = tp;
                    x.lastPosUpdate = openTime;
                    x.isTrailing    = false;
                    bsPos[i] = x;

                    #ifdef dbgOpenOrder ArrayPrint(bsPos[i]); #endif
                    } 
                    
                    else { Print("Error: Could not find the newest position for symbol: ", Symbol); }
                } 
                else { Print("orderSell Fail", " Error: ", GetLastError(), "Tick: ", TicksReceivedCount); }
            }
        void posPartialClose(string sym, long tix, ENUM_POSITION_TYPE type, double vol, double TPmulti, double SLmulti, double ask, double bid, int SymbolLoop, int posArrayIndex ) {
            #ifdef dbgposPartialClose DebugBreak(); #endif
            if( trade.PositionClosePartial(tix, vol, ULONG_MAX) ) { 
                
                int     numValuesNeededATR = 2;
                double  bATR[];
                bool    fillSuccessATR = custCopyBuffer(handle_ATR[SymbolLoop], 0, bATR, numValuesNeededATR, sym, "ATR");
                
                if( type == POSITION_TYPE_BUY ) {
                    double sl = ask - (NormalizeDouble(bATR[1], (int)SymbolInfoInteger(sym, SYMBOL_DIGITS))*SLmulti);
                    trade.PositionModify(tix, sl, NULL);
                    bsPos[posArrayIndex].isTrailing = true;
                    positionInfo.SelectByTicket(tix);
                    bsPos[posArrayIndex].lastPosUpdate = positionInfo.TimeUpdate();
                    }
                    
                    else { 
                        double sl = bid + (NormalizeDouble(bATR[1], (int)SymbolInfoInteger(sym, SYMBOL_DIGITS))*SLmulti);
                        trade.PositionModify(tix, sl, NULL);
                        bsPos[posArrayIndex].isTrailing = true;
                        positionInfo.SelectByTicket(tix);
                        bsPos[posArrayIndex].lastPosUpdate = positionInfo.TimeUpdate();
                        }
                } Print("Partial Position ", tix, " close fail.  Error: ", GetLastError(), "Tick: ", TicksReceivedCount );
            }
        void posModify(string sym, int symbolLoop, int posArrayIndex, long tix, ENUM_POSITION_TYPE type, double ask, double bid) {
            
            positionInfo.SelectByTicket(tix);

            int     numValuesNeededATR = 2;
            double  bATR[];
            bool    fillSuccessATR = custCopyBuffer(handle_ATR[symbolLoop], 0, bATR, numValuesNeededATR, sym, "ATR");
            double  BuySl          = ask - (NormalizeDouble(bATR[1], (int)SymbolInfoInteger(sym, SYMBOL_DIGITS))*iSLmultiplier);
            double  SellSl         = bid + (NormalizeDouble(bATR[1], (int)SymbolInfoInteger(sym, SYMBOL_DIGITS))*iSLmultiplier);
            
            if( type == POSITION_TYPE_BUY && ask > iClose(sym, PERIOD_D1, 1) && BuySl > positionInfo.StopLoss() ) {
                
                if( trade.PositionModify(tix, BuySl, NULL) ) { 
                    bsPos[posArrayIndex].lastPosUpdate = positionInfo.TimeUpdate();
                    PrintFormat("PosTypeMod: Buy | PosTix: %g, | Ask: %g | LastBarClose: %g | BuySL: %g | SLCrnt: %g ", tix, ask, 
                    NormalizeDouble(iClose(sym, PERIOD_D1, 1), _Digits), BuySl, positionInfo.StopLoss() ); 
                    } else Print("Position ", tix, " SL update Failed. Error: ", GetLastError(), " Tick: ", TicksReceivedCount );
                }
                else if( type == POSITION_TYPE_SELL && bid < iClose(sym, PERIOD_D1, 1) && SellSl < positionInfo.StopLoss() ) {
                    if( trade.PositionModify(tix, SellSl, NULL) ) {
                        bsPos[posArrayIndex].lastPosUpdate = positionInfo.TimeUpdate();
                        PrintFormat("PosTypeMod: Sell | Pos: %g, | Bid: %g | LastBarClose: %g | SellSL: %g | SLCrnt: %g ", tix, bid,
                        NormalizeDouble(iClose(sym, PERIOD_D1, 1), _Digits), SellSl, positionInfo.StopLoss() );
                        } else Print("Position ", tix, " SL update Failed. Error: ", GetLastError(), "Tick: ", TicksReceivedCount );
                    } 
            }
    // -- -- Signals -- -- //
        ETRADESIGNAL checkForOpenSignal(int SymbolLoop, string& signalDiagnosticMetrics)    {
            string CurrentSymbol = SymbolArray[SymbolLoop];
            
            //Need to copy values from indicator buffers to local buffers
            int    numValuesNeededMA = 3;   // Number of values to fill indicator buffer. Determined by number of values required for signal logic
            
            double bMAFast[], bMASlow[], bMALong[];
            double CurrentClose = iClose(CurrentSymbol, Period(), 0);

            ETRADESIGNAL openSignal = SIGNAL_NONE;
            
            bool fillSuccessMAFast  = custCopyBuffer(handle_MAFast[SymbolLoop], 0, bMAFast, numValuesNeededMA, CurrentSymbol, "MAFast");
            bool fillSuccessMASlow  = custCopyBuffer(handle_MASlow[SymbolLoop], 0, bMASlow, numValuesNeededMA, CurrentSymbol, "MASlow");
            bool fillSuccessMALong  = custCopyBuffer(handle_MALong[SymbolLoop], 0, bMALong, numValuesNeededMA, CurrentSymbol, "MALong");

            if(fillSuccessMAFast == false  ||  fillSuccessMASlow == false  ||  fillSuccessMALong == false)
                return(SIGNAL_ERROR);     //No need to log error here. Already done from custCopyBuffer() function
            
            #ifdef dbgcheckMAOpen PrintFormat("MAvalue check- MAFast2 %d, MASlow2 %d, MAFast1 %d, MASlow1 %d, MALong2 %d, MALong1 %d", bMAFast[1], bMASlow[1], bMAFast[0], bMASlow[0], bMALong[1], bMALong[0]); #endif
            
            
            // Trade Signal Logic
            if ( checkTimeRange(startHr, startMn, endHr, endMn) == true ) {    
                
                ETRADESIGNAL openPosSignal = checkOpenPositions(CurrentSymbol);

                if( openPosSignal != SIGNAL_POSOPEN_BOTH ) {
                    if( openPosSignal == SIGNAL_POSOPEN_NONE || openPosSignal == SIGNAL_POSOPEN_SELL ) {
                        if( ( bMAFast[1] <= bMALong[1] && bMAFast[0] >= bMALong[0] ) || 
                            ( bMAFast[0] >= bMALong[0] && bMASlow[0] >= bMALong[0] && 
                              bMAFast[1] < bMASlow[1] && bMAFast[0] > bMASlow[0] ) ) { openSignal = SIGNAL_BUY; }
                        }
                    if( openPosSignal == SIGNAL_POSOPEN_NONE || openPosSignal == SIGNAL_POSOPEN_BUY ) {
                        if( ( bMAFast[1] >= bMALong[1] && bMAFast[0] <= bMALong[0]) || 
                            ( bMAFast[0] <= bMALong[0] && bMASlow[0] <= bMALong[0] && 
                            bMAFast[1] > bMASlow[1] && bMAFast[0] < bMASlow[0] ) ) { openSignal = SIGNAL_SELL; }
                        }
                    } 
            #ifdef dbgOpenSignal StringConcatenate(signalDiagnosticMetrics, 
                                "MAFast2=",  DoubleToString(bMAFast[1], (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)), 
                                " MASlow2=", DoubleToString(bMASlow[1], (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)), 
                                " MAFast1=", DoubleToString(bMAFast[0], (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)), 
                                " MASlow1=", DoubleToString(bMASlow[0], (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)), 
                                " CLOSE=" + DoubleToString(CurrentClose, (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)),
                                " OpnPosSig: ", openPosSignal, " OpnSig: ", openSignal); #endif
                }
             
            return(openSignal); 
            }
        ETRADESIGNAL checkForCloseSignal(int SymbolLoop, string& signalDiagnosticMetrics)   {
            string CurrentSymbol = SymbolArray[SymbolLoop];
            
            //Need to copy values from indicator buffers to local buffers
            int    numValuesNeeded = 3;
            double bMAFast[], bMASlow[];
            
            ETRADESIGNAL closeSignal = SIGNAL_NONE;

            bool fillSuccessMAFast = custCopyBuffer(handle_MAFast[SymbolLoop], 0, bMAFast, numValuesNeeded, CurrentSymbol, "MAFast");
            bool fillSuccessMASlow = custCopyBuffer(handle_MASlow[SymbolLoop], 0, bMASlow, numValuesNeeded, CurrentSymbol, "MASlow");
            
            if(fillSuccessMAFast == false  ||  fillSuccessMASlow == false)
                return(SIGNAL_ERROR);     //No need to log error here. Already done from custCopyBuffer() function
            
            double CurrentClose = iClose(CurrentSymbol, Period(), 0);
            
            // Trade Signal Logic    
                
                ETRADESIGNAL openPosSignal = checkOpenPositions(CurrentSymbol);
                
                if ( openPosSignal !=  SIGNAL_POSOPEN_NONE ) { 
                     
                if ( (  openPosSignal ==  SIGNAL_POSOPEN_BOTH || openPosSignal ==  SIGNAL_POSOPEN_SELL ) &&
                        bMAFast[1] <= bMASlow[1] && bMAFast[0] > bMASlow[0] ) { 
                        closeSignal = SIGNAL_CLOSE_SELL; }
                   
                    else if ( (  openPosSignal ==  SIGNAL_POSOPEN_BOTH || openPosSignal ==  SIGNAL_POSOPEN_BUY ) && 
                            bMAFast[1] >= bMASlow[1] && bMAFast[0] < bMASlow[0] ) { 
                            closeSignal = SIGNAL_CLOSE_BUY; }
                   }
                
           #ifdef dbgCloseSignal StringConcatenate(signalDiagnosticMetrics, 
                            "MAFast2=",  DoubleToString(bMAFast[1], (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)), 
                            " MASlow2=", DoubleToString(bMASlow[1], (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)), 
                            " MAFast1=", DoubleToString(bMAFast[0], (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)), 
                            " MASlow1=", DoubleToString(bMASlow[0], (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)), 
                            " CLOSE=" +  DoubleToString(CurrentClose, (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)),
                            " OpnPosSig: ", openPosSignal, " ClsSig: ", closeSignal); #endif

                return(closeSignal);
         }
        
        ETRADESIGNAL checkOpenPositions(string CurrentSymbol) {             //  Limits the number of simultaneous Positions to user designated quantity
            
            int sTradeCnt = 0;                          //  Sell position counter
            int bTradeCnt = 0;                          //  Buy position counter
            int mPositionsCnt = PositionsTotal();       //  Quantity of current positions
            int mMagic = iMagic;
            int i = 0;                                  //  'for' index
            
            string symbol = CurrentSymbol;

            posOpnSglPs = SIGNAL_POSOPEN_NONE;

            if(mPositionsCnt == 0) { return(posOpnSglPs); }               //  If no positions open, check is ok, return true
                
                #ifdef dbgCheckOpen PrintFormat("Fnc1: %s, No Open Positions - posSigPass: %d", 
                __FUNCSIG__, posOpnSglPs); #endif
                
                for(i=0; i<mPositionsCnt; i++) {                                   //  Routine to check all open position types
                        ulong tx = PositionGetTicket(i);                                //  Stored position ticket number
                    if (tx > 0 && PositionSelectByTicket(tx)) {                         //  If positions are found, get ticket number at index
                        ulong  posMagicNum   =   PositionGetInteger(POSITION_MAGIC);    //  Position's EA magic number
                        ulong  posType       =   PositionGetInteger(POSITION_TYPE);     //  Position Type
                        string posSym        =   PositionGetString(POSITION_SYMBOL);    //  Position Symbol
                        
                        if (posSym == symbol && posMagicNum == mMagic &&                //  If symbol, EA Mg# and Type is Sell, increment Sell Poition count
                            posType==POSITION_TYPE_SELL) { sTradeCnt++; }
                        if (posSym == symbol && posMagicNum==mMagic && 
                            posType==POSITION_TYPE_BUY) { bTradeCnt++; }           //  If EA Mg# match and Type is Buy, increment Buy Poition count 
                        }
                    }
                
                    if      ( sTradeCnt >  0 && bTradeCnt > 0 )  { posOpnSglPs = SIGNAL_POSOPEN_BOTH; }  // Set posOpnSglPs to both: if Buy and Sell position types are open
                    else if ( sTradeCnt == 0 && bTradeCnt > 0 )  { posOpnSglPs = SIGNAL_POSOPEN_BUY;  }  // Set posOpnSglPs to buy: if Buy positions but NOT Sell positions are open
                    else if ( sTradeCnt >  0 && bTradeCnt == 0)  { posOpnSglPs = SIGNAL_POSOPEN_SELL; }  // Set posOpnSglPs to buy: if sell positions but NOT buy positions are open
    
            #ifdef dbgCheckOpen PrintFormat("Fnc2: %s, bPosCnt: %d, sPosCnt: %d, PosChkSig: %d", __FUNCSIG__, bTradeCnt, sTradeCnt, posOpnSglPs); #endif
           
            return(posOpnSglPs);
            }

        bool checkTimeRange(int stHr, int stMn, int eHr, int eMn) {         // Method to set a trade timerange
            int mStartTime = stHr*60+stMn;  // Set start time variable in minutes
            int mEndTime   = eHr*60+eMn;    // Set end time variable in minutes
            int mNow;                       // Create variable to store current server time
            
            MqlDateTime mqlNow;             // create variable of std structure mqldatetime for access to current hour and minute  
                
                // Check function initialization
                    if (!(0<=stHr && stHr<=23)) {
                        Print("Start hour must be from 0-23 ", GetLastError(), "Tick: ", TicksReceivedCount);
                        chkTRPass = SIGNAL_NONE; }
                        else if (!(0<=stMn && stMn<=59)) {
                            Print("Start min must be from 0-59 ", GetLastError(), "Tick: ", TicksReceivedCount);
                            chkTRPass = SIGNAL_NONE; }
                        else if (!(0<=eHr && eHr<=23)) {
                            Print("End hour must be from 0-23 ", GetLastError(), "Tick: ", TicksReceivedCount);
                            chkTRPass = SIGNAL_NONE; }
                        else if (!(0<=eMn && eMn<=59)) {
                            Print("End min must be from 0-59 ", GetLastError(), "Tick: ", TicksReceivedCount);
                            chkTRPass = SIGNAL_NONE; }
                        else
                
                TimeCurrent(mqlNow);                // Get current server time
                mNow = mqlNow.hour*60+mqlNow.min;   // Store current server time in minutes in a variable

                if(mStartTime == 0 && mEndTime==0 ) { return(true);}             // If no time range set, default to all times ok
                else if ( (mStartTime<mEndTime && mNow>=mStartTime && mNow<=mEndTime)               // Check start not after end; Check now is between start and end            
                        || (mEndTime<mStartTime && (mNow>=mStartTime || mNow<=mEndTime)) )  
                        { return(true); }                                        // Set signal
                else return(false);                                              // If start times are not equal to zero and fall outside of range, set signal to none
                #ifdef dbgCheckTimeRange PrintFormat("Func: %s, CrntTime: %d, SignalPass: $d", 
                                                    __FUNCSIG__, mNow, chkTRPass); #endif    
            }                
        
    // -- -- Working Functions  -- -- //
        double orderVolumeBuy(double volFac, double maxOrder, string Symbol)  {        // Calculate order volume based on account balance and user input percent of
            volumeBuyPass = 0;                                                          //  initialize result value to 0
            
            double mBalance     = AccountInfoDouble(ACCOUNT_BALANCE);       //  Store current account value
            double mBid         = SymbolInfoDouble(Symbol, SYMBOL_BID);     //  Get current bid price; used in vol calculation
            double mMaxOrder    = maxOrder/100;                             //  Factor to calulate user defined %of account allowed to trade
            double mVol         = 0;                                        //  Initialize final value to 0                            
            double mVolFac      = volFac/1000;                              //  Allows user input to manipulate final volume calulation.  Probably not useful. consider removing.
            double mVolMin      = SymbolInfoDouble(Symbol, SYMBOL_VOLUME_MIN);
            
            mVol = ((mBalance * mMaxOrder) / mBid) * mVolFac;               //  Calculates percent of acct balance and divides by current price, then converts to micro lots
            
            if( mVol < mVolMin ) {
                volumeBuyPass = NormalizeDouble(mVolMin, 2);                //  Reduces calculated value to 2 decimal places to fit requied format
                } else volumeBuyPass   =   NormalizeDouble(mVol, 2);

            #ifdef volumeOrderBuy PrintFormat("Function: %s, Acct Balance: %f, Bid: %f, volFact: %f, MaxOrd: %f, BuyVol: %f, VolNorm: %f", __FUNCTION__, mBalance, mBid, mVolFac, mMaxOrder, mVol, volumeBuyPass); #endif
            
            return volumeBuyPass;   //  Store volume for trade function
            }
        double orderVolumeSell(double volFac, double maxOrder, string Symbol)  {       // See orderVolumeBuy
            volumeSellPass = 0;
            
            double mAsk = SymbolInfoDouble(Symbol, SYMBOL_ASK);
            double mBalance = AccountInfoDouble(ACCOUNT_BALANCE);            
            double mMaxOrder = maxOrder/100;
            double mVol = 0;
            double mVolFac = volFac/1000;
            double mVolMin      = SymbolInfoDouble(Symbol, SYMBOL_VOLUME_MIN);

            mVol = ((mBalance * mMaxOrder) / mAsk) * mVolFac;
            
            if( mVol < mVolMin ) {
                volumeSellPass   =   NormalizeDouble(mVolMin, 2);               //  Reduces calculated value to 2 decimal places to fit requied format
                } else volumeSellPass = NormalizeDouble(mVol, 2);
            
            #ifdef volumeOrderSell PrintFormat("Function: %s, Acct Balance: %f, Ask: %f, volFact: %f, MaxOrd: %f, SellVol: %f, VolNorm: %f", __FUNCTION__, mBalance, mAsk, mVolFac, mMaxOrder, mVol, volumeSellPass); #endif
            
            return volumeSellPass;
            }
        bool createTPSL(double TPmulti, double SLmulti, ETRADESIGNAL TradeDirection, 
                        string CurrentSymbol, int SymbolLoop) {             // Calculates take profit and stop loss for buy and sell signals. 
                                                                            // Note this does not yet cover situations in which the signal is "BOTH"
                                                                            // Note CurrentSymbol is passed in as a check the correct symbol is being used.
            if (TradeDirection == 0) { return(false); }
            
            double bATR[];
            double mAsk     =   SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK);
            double mBid     =   SymbolInfoDouble(CurrentSymbol, SYMBOL_BID);
            
            int    mDigits  =   (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS);  
            int    numValuesNeededATR = 1;

            bool fillSuccessATR     = custCopyBuffer(handle_ATR[SymbolLoop], 0, bATR, numValuesNeededATR, CurrentSymbol, "ATR");
            
            sTP = 0; sSL = 0;       // Ensure values at 0 to start
            bTP = 0; bSL = 0;       // Ensure values at 0 to start

            if      (fillSuccessATR == false) {                
                Print("ATR Create error: ", GetLastError(), "Tick: ", TicksReceivedCount);
                return(false);
                }

            else if (TradeDirection == 2) {
                bTP = mAsk + (NormalizeDouble(bATR[0], mDigits)*TPmulti); 
                bSL = mAsk - (NormalizeDouble(bATR[0], mDigits)*SLmulti);
                #ifdef dbgPriceExit Print("Fnc: ", __FUNCSIG__, "Ask: ", NormalizeDouble(mAsk, mDigits), " ATR Value: ", NormalizeDouble(bATR[0], mDigits), " TP value: ", bTP, " SL value: ", bSL); #endif
                return(true);
                }

            else if (TradeDirection == 3) {
                sTP = mBid - (NormalizeDouble(bATR[0], mDigits)*TPmulti); 
                sSL = mBid + (NormalizeDouble(bATR[0], mDigits)*SLmulti);
                #ifdef dbgProfit Print("Ask: ", mBid, " ATR Value: ", NormalizeDouble(bATR[0], mdigits), " TP value: ", sTP, " SL value: ", sSL); #endif
                return(true);
                }
            
            //StringConcatenate(signalDiagnosticMetrics, "ATR=", DoubleToString(bATR[0], mdigits));
            return(false);
            }         

        void checkUpdatePosition(int SymbolLoop, string& signalDiagnosticMetrics) {
            #ifdef dbgcheckUpdatePosition  #endif
            if (iTrailingON == false) { return; }   // **********This should change.  TP could get hit and then leave when outside time window.

            string              CurrentSymbol   = SymbolArray[SymbolLoop];
            datetime            currentTime     = TimeCurrent();
            string              posSym          = "";
            datetime            lastPosModTime  = 0;
            double              vol             = 0;
            double              ask             = 0;
            double              bid             = 0;
            double              volMin          = SymbolInfoDouble(CurrentSymbol, SYMBOL_VOLUME_MIN);
            int                 sHr             = 16;
            int                 sMn             = 50;
            int                 eHr             = 16;
            int                 eMn             = 59;
            int                 posArrayIndex   = -1;
            ENUM_POSITION_TYPE  posType         = POSITION_TYPE_BUY;
            long                tix             = 0;

            // Retrieve symbol prices safely
            if (!SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK, ask) || !SymbolInfoDouble(CurrentSymbol, SYMBOL_BID, bid)) {
                Print("Error retrieving prices for symbol: ", CurrentSymbol);
                return;
                }

            // Store total positions to avoid recalculation in the loop
            int totalPositions = PositionsTotal();

            for (int i = 0; i < totalPositions; i++) {

                // Select positions and fill variables
                if (positionInfo.SelectByIndex(i)) {
                    tix     = PositionGetInteger(POSITION_TICKET);
                    posSym  = positionInfo.Symbol();
                    vol     = NormalizeDouble((positionInfo.Volume()) * 0.8, 2);
                    posType = positionInfo.PositionType();

                    if (vol <= volMin) { vol = volMin; }

                    for (int t = ArraySize(bsPos) - 1; t >= 0; t--) {
                        posArrayIndex   = t;
                        lastPosModTime  = bsPos[t].lastPosUpdate;

                        // Find position in bsPos array:
                        // Check selected position matches position ID and current symbol
                        // Ensure position was not already modified on this bar
                        if (CurrentSymbol == posSym && bsPos[t].posID == tix) {

                            // Check if this is order's 1st TP phase or trailing phase
                            if (bsPos[t].isTrailing == false) {

                                // Check position type and if price has reached TP
                                if (posType == POSITION_TYPE_BUY && bsPos[t].tp <= ask) {
                                    posPartialClose(CurrentSymbol, tix, posType, vol, iTPmultiplier, iSLmultiplier, ask, bid, SymbolLoop, posArrayIndex);
                                } else if (posType == POSITION_TYPE_SELL && bsPos[t].tp >= bid) {
                                    posPartialClose(CurrentSymbol, tix, posType, vol, iTPmultiplier, iSLmultiplier, ask, bid, SymbolLoop, posArrayIndex);
                                }

                            } else if (checkTimeRange(sHr, sMn, eHr, eMn) && (currentTime - lastPosModTime > 86400)) {

                                // Position is trailing, check if SL needs modification
                                posModify(CurrentSymbol, SymbolLoop, posArrayIndex, tix, posType, ask, bid);
                             }

                            #ifdef dbgcheckUpdatePosition 
                            dbgpositionArrayCount = ArraySize(bsPos); 
                            Print("Positions Array size: ", dbgpositionArrayCount);
                            #endif
                            }
                        }
                    }
                }
            }
        
        void positionArrayMaintenance() {
            int size = ArraySize(bsPos);
            for(int i=size-1; i>=0; i--) {
                ulong ticket = bsPos[i].posID;
                if (!PositionSelectByTicket(ticket)) {                             // Check if position is still open
                    ArrayRemove(bsPos, i, 1);                                      // Remove from array if closed
                    ArrayResize(bsPos, ArraySize(bsPos));                          // Resize Array
                    Print("Removed closed position with ticket: ", ticket, "Array Size: ", ArraySize(bsPos));
                    
                    }
                }
            }
    // -- -- Template Functions -- -- //    
        /*
        string Check[INDICATOR]OpenSignalStatus(int SymbolLoop, string& signalDiagnosticMetrics)   {
            string CurrentSymbol = SymbolArray[SymbolLoop];
            
            //Need to copy values from indicator buffers to local buffers
            int    numValuesNeeded = 3; // Number of values to fill indicator buffer. Determined by number of values required for signal logic
            double bINDICATOR[];
            
            
            bool fillSuccessINDICATOR = custCopyBuffer(handle_INDICATOR[SymbolLoop], 0, bINDICATOR, numValuesNeeded, CurrentSymbol, "INDICATOR");
            
            if(fillSuccessINDICATOR == false  ||  fillSuccessINDICATOR2 == false)
                return("FILL_ERROR");     //No need to log error here. Already done from custCopyBuffer() function
            
            double crtINDICATOR = bINDICATOR[0];
            double crtINDICATOR2 = bINDICATOR2[0];
            
            double CurrentClose = iClose(CurrentSymbol, Period(), 0);
            
            //SET METRICS FOR BBANDS WHICH GET RETURNED TO CALLING FUNCTION BY REF FOR OUTPUT TO CHART
            StringConcatenate(signalDiagnosticMetrics, "????=", DoubleToString(CurrentINDICATOR, (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)), "  |  LOWER=", DoubleToString(CurrentINDICATOR2, (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)), "  |  CLOSE=" + DoubleToString(CurrentClose, (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS)));
            
            
            //INSERT YOUR OWN ENTRY LOGIC HERE
            //e.g.
            //if(CurrentClose > CurrentINDICATOR)
            //   return("SHORT");
            //else if(CurrentClose < CurrentINDICATOR)
            //   return("LONG");
            //else
                return("NO_TRADE");
        }
        */
    /*
    if( positionInfo.PositionType() == POSITION_TYPE_BUY ) {
                            
                            if( bsPos[t].tp <= ask ) { 
                                
                                 
                                
                               

                                        if(  ) {  
                                            bsPos[t].lastPosUpdate = positionInfo.TimeUpdate();
                                            #ifdef dbgcheckUpdatePosition PrintFormat( "Position: %g modified | StopLoss: %g | TakeProfit: %g | PosTimeUpdate: %s | TickCount: %g", tix, sl, tp, TimeToString(bsPos[t].lastPosUpdate, TIME_DATE), TicksReceivedCount); #endif
                                            } 
                                            else Print("Position: ", tix, " modify fail. Error: ", GetLastError());
                                    } 
                                    else Print("Partial close fail! Position: ", tix,  " Error: ", GetLastError());                                
                                } 
                            }
                             else if ( bsPos[t].posID == tix && positionInfo.PositionType() == POSITION_TYPE_SELL ) {

                                if( bsPos[t].tp >= bid ) {
                                    
                                    if( vol <= volMin ) { vol = volMin; }
                                    
                                    if( trade.PositionClosePartial(tix, vol, ULONG_MAX) ) { 
                                        int    numValuesNeededATR = 1;
                                        double bATR[];
                                        bool fillSuccessATR = custCopyBuffer(handle_ATR[SymbolLoop], 0, bATR, numValuesNeededATR, CurrentSymbol, "ATR");
                                        //tp = bid - (NormalizeDouble(bATR[0], (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS))*TPmulti); 
                                        sl = bid + (NormalizeDouble(bATR[0], (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS))*SLmulti);

                                            if( trade.PositionModify(tix, sl, NULL) ) { 
                                                bsPos[t].lastPosUpdate = positionInfo.TimeUpdate();
                                                #ifdef dbgcheckUpdatePosition PrintFormat( "Position: %g modified | StopLoss: %g | TakeProfit: %g | PosTimeUpdate: %s | TickCount: %g", tix, sl, tp, TimeToString(bsPos[t].lastPosUpdate, TIME_DATE), TicksReceivedCount); #endif
                                                } 
                                                else Print("Position: ", tix, " modify fail. Error: ", GetLastError());
                                        } 
                                        else Print("Partial close fail! Position: ", tix,  " Error: ", GetLastError());
                                    }
                                }
                            }
                        }
                    }
                }
            }

 