// iColour is the colour for the box
//
// oX, oY, oColour and oPlot should be wired to the appropriate ports on the VGA controller
//

// Some constants are set as parameters to accommodate the different implementations
// X_SCREENSIZE, Y_SCREENSIZE are the dimensions of the screen
//       Default is 160 x 120, which is the size for the DE1_SoC vga controller
// CLOCKS_PER_SECOND should be the frequency of the clock being used.

//toplevel: takes in DE1-SoC keys and switches


module bounce(iColour,iResetn,iClock,oX,oY,oColour,oPlot);
    input wire [2:0] iColour;
    input wire 	    iResetn;
    input wire 	    iClock;
    output wire [7:0] oX;         // VGA pixel coordinates
    output wire [6:0] oY;

    output wire [2:0] oColour;     // VGA pixel colour (0-7)
    output wire 	     oPlot;       // Pixel drawn enable

    wire FrameRateEN, FrameMoveEN;
    wire [10:0]DelayCNT, FrameCNT;
    wire [7:0] x_coord;
    wire [6:0] y_coord;
    wire [2:0] colour;

    parameter
        X_SCREENSIZE = 160,  // X screen width for starting resolution and fake_fpga
        Y_SCREENSIZE = 120,  // Y screen height for starting resolution and fake_fpga
        CLOCKS_PER_SECOND = 5000, // 5 KHZ for fake_fpga
        X_BOXSIZE = 8'd4,   // Box X dimension
        Y_BOXSIZE = 7'd4,   // Box Y dimension
        X_MAX = X_SCREENSIZE - 1 - X_BOXSIZE, // 0-based and account for box width
        Y_MAX = Y_SCREENSIZE - 1 - Y_BOXSIZE,
        PULSES_PER_SIXTIETH_SECOND = CLOCKS_PER_SECOND / 60;

    assign FrameRateEN = (DelayCNT == 11'b0000) ? 1 : 0; //if DelayCNT is set to 0, set FrameRateEN to 1 (allow FrameRate to )
    Counter DelayCounter(.clock(iClock), .resetn(iResetn), .Clear_b(1'b0), .CycleNum(CLOCKS_PER_SECOND/60), .PulseCount(DelayCNT));

    assign FrameMoveEN = (FrameCNT == 11'b0000)?1:0;	   
    Counter FrameCounter(.clock(iClock), .resetn(iResetn), .Clear_b(1'b0), .CycleNum(CLOCKS_PER_SECOND/4), .PulseCount(FrameCNT));

    mainControl mainCtl(.resetn(iResetn), 
                        .clk(iClock), 
                        .iColour(iColour),
                        .FrameRateEN(FrameRateEN),
                        .FrameMoveEN (FrameMoveEN),
                        .xMAX(X_MAX),
                        .yMAX(Y_MAX),
                        .colour(colour),
                        .XCounter(x_coord), 
                        .YCounter(y_coord),
                        .startPlot(startPlot), 
                        .plotDone(plotDone)	);

    drawBox drawVGA (.resetn(iResetn), 
					.clock(iClock), 
					.colour(colour), 
					.x_coord(x_coord), 
					.y_coord(y_coord), 
					.x_boxsize(X_BOXSIZE), 
					.y_boxsize(Y_BOXSIZE), 
					.startPlot(startPlot), 
					.plotDone(plotDone), 
					.oPlot(oPlot), 
					.oColour(oColour), 
					.oX(oX), 
					.oY(oY));

endmodule // bounce


//main FSM
module mainControl(resetn, clk, iColour, plotDone, FrameRateEN, FrameMoveEN, xMAX, yMAX, XCounter, YCounter, colour, startPlot);
	input resetn, clk, plotDone, FrameRateEN, FrameMoveEN;
	input [2:0] iColour;
	input [7:0] xMAX;
	input [6:0] yMAX;
	output reg [7:0] XCounter;
	output reg [6:0] YCounter;
	output reg [2:0] colour;
	output reg startPlot;
	
	reg DirH, DirY, ld_black, ld_colour, update_XY;

    reg [5:0] current_state, next_state; 
    
    localparam  S_IDLE			= 6'b0,
				S_1stPLOT		= 6'd1,
				S_WAIT_ERASE	= 6'd2,
				S_ERASE         = 6'd3,
                S_UPDATE_XY     = 6'd4,
				S_WAIT_PLOT     = 6'd5,
                S_PLOT			= 6'd6; 

    
    // State diagram logic
    always@(*)
    begin: state_table 
            case (current_state)
                S_IDLE: next_state = S_1stPLOT;
				S_1stPLOT: next_state = S_WAIT_ERASE;
                S_WAIT_ERASE: next_state = FrameMoveEN ? S_ERASE : S_WAIT_ERASE; 
                S_ERASE: next_state = S_UPDATE_XY;
                S_UPDATE_XY: next_state = S_WAIT_PLOT;
                S_WAIT_PLOT: next_state = FrameRateEN ? S_PLOT : S_WAIT_PLOT;            
                S_PLOT: next_state = S_WAIT_ERASE;
            default: next_state = S_IDLE;
        endcase
    end
   

    // This controls each state's outputs that then feed into the main datapath
    always @(*)
    begin: enable_signals
	startPlot = 1'b0;
	ld_black  =1'b0;
	update_XY = 1'b0;
	ld_colour = 1'b0;

        case (current_state)
            S_IDLE: ld_colour = 1'b1;			
            S_1stPLOT: startPlot = 1'b1;
            S_WAIT_ERASE: ld_black = 1'b1;
            S_ERASE: startPlot = 1'b1;
			S_UPDATE_XY: update_XY = 1'b1;
			S_WAIT_PLOT: ld_colour = 1'b1;
            S_PLOT: startPlot= 1'b1;
			default: 
            begin //default needs begin and end if no content
			end
        endcase
    end
   
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if (!resetn) current_state <= S_IDLE;
        else current_state <= next_state;
    end

    //set black or to desired colour
    always@(posedge clk) 
    begin
        if (!resetn) colour = 3'b0;
        else 
        begin
            if (ld_black) colour = 3'b0; 
            else if (ld_colour) colour = iColour;
        end
    end	


    always@(posedge clk) 
    begin
        if (!resetn) //reset the counter to 0
        begin	
            XCounter <= 8'b0;
            YCounter <= 8'b0;	
        end
    else
    begin
        if (update_XY) //count up or down, according to the H or Y direction being true (positive) or false (negative)
        begin
            XCounter <= DirH ? XCounter + 1 : XCounter - 1;
            YCounter <= DirY ? YCounter - 1 : YCounter + 1;	
        end   
    end
    end

    //handle bouncing!
    always@(posedge clk)
    begin
        if (!resetn) DirH <= 8'b1;
        else
        begin
            if ((XCounter == xMAX) && (DirH == 1)) DirH <= 1'b0; //if the pixel is already at the right limit, then make it go left
            else if ((XCounter == 8'b0) && (DirH == 0)) DirH <= 1'b1; //if the pixel is already at the left limit, then make it go right
        end
    end

    //handle more bouncing
    always@(posedge clk) 
    begin
        if (!resetn) DirY <= 8'b1;
        else 
        begin
            if ((YCounter == xMAX) && (DirY == 0)) DirY <= 1'b1; //if the pixel is already at the bottom limit, then make it go up
            else if((YCounter == 8'b0) && (DirY == 1)) DirY <=1'b0; //if the pixel is already at the top extreme, then make it go down
        end    
    end	

endmodule


//rate divider
module Counter(clock, resetn, Clear_b, CycleNum, PulseCount);
    //inputs
    input clock, resetn, Clear_b;
    input [10:0] CycleNum;
    
    //output
    output reg [10:0] PulseCount;

    always @(posedge clock)
        begin
        if (!resetn) PulseCount <= CycleNum - 1; // reset to default value
        else if (Clear_b == 1'b1) // reset the counter if we reload the letter
            PulseCount <= CycleNum - 1;			
        else if (PulseCount == 11'b00000000000)// Check if parallel load
            PulseCount <= CycleNum - 1;
        else PulseCount <= PulseCount - 1; // count down to zero
        end

endmodule

//=============================================================================================================================
//THE FOLLOWING FSM AND DATAPATH HANDLE THE ACTUAL DRAWING OF THE PIXEL
//=============================================================================================================================

//drawBox brings box-drawing controller and datapath together
module drawBox (resetn, clock, colour, x_coord, y_coord, x_boxsize, y_boxsize, startPlot, plotDone, oPlot, oColour, oX, oY);
    //inputs
    input resetn, clock;
    input [2:0] colour;
    input [7:0] x_boxsize, x_coord;
    input [6:0] y_boxsize, y_coord;
    input wire startPlot;
    
    //outputs
    output wire plotDone, oPlot;
    output wire [2:0] oColour;  
    output wire [7:0] oX;        
    output wire [6:0] oY;  

    //connections
    wire [7:0] plot_x, target_x;
    wire [6:0] plot_y,  target_y;
    wire ld_data, draw, ld_orgX, incr_x, incr_y;

    drawBoxControl drawCtl(.clk(clock),
                            .resetn(resetn), 
                            .startPlot(startPlot), 
                            .plot_x(plot_x), 
                            .plot_y(plot_y), 
                            .target_x(target_x),  
                            .target_y(target_y), 
                            .ld_data(ld_data), 
                            .draw(draw),
                            .ld_orgX(ld_orgX),
                            .incr_x(incr_x),
                            .incr_y(incr_y),
                            .plotDone(plotDone)
                            );
                            
    drawBoxDatapath drawDpath(.clk(clock),
                            .resetn(resetn), 
                            .colour(colour),
                            .x_coord(x_coord),
                            .y_coord(y_coord),
                            .x_boxsize(x_boxsize),
                            .y_boxsize(y_boxsize),  
                            .ld_data(ld_data), 
                            .draw(draw ),
                            .ld_orgX(ld_orgX),
                            .incr_x(incr_x),
                            .incr_y(incr_y),    
                            .plot_x(plot_x), 
                            .plot_y(plot_y), 
                            .target_x(target_x),  
                            .target_y(target_y), 						  
                            .oPlot(oPlot), 
                            .oColour(oColour), 
                            .oX(oX),
                            .oY(oY)
                            );

endmodule

//handles box drawing controller (FSM)
module drawBoxControl(clk, resetn, startPlot, plot_x, target_x, plot_y, target_y, ld_data, draw, ld_orgX, incr_x, incr_y, plotDone);
    //inputs
    input clk, resetn, startPlot;
	input [7:0] plot_x,	target_x;
	input [6:0] plot_y, target_y;
  
    //outputs
    output reg ld_data, draw, ld_orgX, incr_x, incr_y, plotDone;
    
    reg [5:0] current_state, next_state; 
    
    //define directive to add alias to state, to make it easier to read to initialize states
    localparam  S_IDLE	       	 = 6'd0,
                S_LOAD_DATA      = 6'd1,
                S_DRAW           = 6'd2,
				S_DONE 			 = 6'd5; //CHANGE BACK TO 3
    
    // State diagram logic
    always@(*)
    begin: state_table 
            case (current_state)
                S_IDLE: next_state = startPlot ? S_LOAD_DATA : S_IDLE;
                S_LOAD_DATA: next_state = S_DRAW;
                //if we are plotting the last pixel, then we can move on to the Done state, otherwise keep drawing \/
                S_DRAW: next_state = ((plot_x == target_x) && (plot_y == target_y)) ? S_DONE : S_DRAW; 
                S_DONE: next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    // This controls each state's outputs that then feed into the main datapath
    always @(*)
    begin: enable_signals
        // By default make all our signals 0
        ld_data = 1'b0;
        draw = 1'b0;
        ld_orgX = 1'b0;
        incr_x = 1'b0;
        incr_y = 1'b0;
        plotDone = 1'b0;

        case (current_state)
            S_IDLE: 
            begin
				ld_data = 1'b0;
				draw = 1'b0;
				ld_orgX = 1'b0;
				incr_x = 1'b0;
				incr_y = 1'b0;
				plotDone = 1'b1;			
            end
            S_LOAD_DATA: 
            begin
                ld_data = 1'b1;
				plotDone = 1'b0;	
            end
            S_DRAW: begin draw = 1'b1;
            end
			S_DONE: begin plotDone = 1'b1;
            end
        endcase
    end
   
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if (!resetn) current_state <= S_IDLE;
        else current_state <= next_state;
    end
endmodule

//handles the box drawing datapath
module drawBoxDatapath(clk, resetn, colour, x_coord, x_boxsize, y_coord, y_boxsize, ld_data, ld_orgX, incr_x, incr_y, draw, oPlot, oColour, plot_x, target_x, oX, plot_y, target_y, oY);
    
    //inputs
    input clk, resetn, incr_x, incr_y, ld_data, ld_orgX, draw;
	input [2:0] colour;
    input [7:0] x_coord, x_boxsize;
	input [6:0] y_coord, y_boxsize;
	
    //outputs
    output reg oPlot;
	output reg [2:0] oColour;
    output reg [7:0] plot_x, target_x, oX;
	output reg [6:0] plot_y, target_y, oY;
	
	reg [7:0] temp_x_coord; //stores x_coord, the starting pixel's x coordinate
	
	
    always@(posedge clk)
    begin
        if (!resetn) //clear the registers
        begin
            target_x <= 8'b0; 			
            target_y <= 7'b0; 	
            temp_x_coord <= 8'b0;
        end
        else
        begin
            if (ld_data)
            begin //set the target (destination) coordinates
                target_x <= (x_coord + x_boxsize - 1);		
                target_y <= (y_coord + y_boxsize - 1);
                temp_x_coord <= x_coord;
            end
        end
    end
   
   //handles the drawing on each pixel
    always@(posedge clk)
    begin
        if (!resetn) //clear all registers
        begin
            oPlot <= 1'b0;
            oX <= 8'b0;
            oY <= 7'b0;
            oColour <= 3'b0;
        end
        else
        begin
            if (draw) //take everything from the registers as output (to then throw into VGA adapters)
            begin
                oPlot <= 1'b1; //plotting is complete		
                oX <= plot_x; 
                oY <= plot_y;
                oColour <= colour;
            end
            else oPlot <= 1'b0; //if we're not drawing, i.e. we haven't drawn the pixel yet
        end
    end
	

    always@(posedge clk) 
    begin
        if (!resetn) //clear the registers
        begin
			plot_x <= 8'b0;
			plot_y <= 7'b0;
        end
        else 
        begin
            if (ld_data) //if we load the data
            begin
                plot_x <= x_coord; //plot_x is set to the initial x coord
				plot_y <= y_coord; //plot_y is set to the initial y coord
			end
			else if (plot_x == target_x) //if we reach the end of the row in the square, go down the next row fom left to right again
            begin
				plot_x <= temp_x_coord; //set plot_x back to the first x value (the first column)
				plot_y <= plot_y + 1; //increment y (go down a row to start going through the row from x_coord again)
			end
			else //if we haven't reached the end of the row yet
            begin
				plot_x <= plot_x + 1; //increment x, i.e. go to the next column...
				plot_y <= plot_y; //... on the same row
			end
        end
    end	

endmodule
//end of drawBoxDatapath module