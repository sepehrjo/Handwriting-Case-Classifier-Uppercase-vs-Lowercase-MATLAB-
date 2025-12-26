function LowercaseUppercase
    %% --- Main Figure & UI Setup ---
    % Create the main GUI figure window with a defined size and title.
    hFig = figure('Name','Handwriting Analysis','NumberTitle','off',...
        'Position',[100,100,950,650]);
    
    % Create an axes object for displaying the processed image.
    hAx = axes('Parent',hFig, 'Units','pixels','Position',[50,250,350,350]);
    axis off;  % Hide axis ticks for a clean image view.
    
    % Create UI buttons for each major processing step.
    uicontrol('Parent',hFig, 'Style','pushbutton',...
        'String','Upload Image',...
        'Position',[450,570,150,40],...
        'Callback',@uploadImageCallback);
    
    uicontrol('Parent',hFig, 'Style','pushbutton',...
        'String','Preprocess Image',...
        'Position',[450,510,150,40],...
        'Callback',@preprocessCallback);
    
    uicontrol('Parent',hFig, 'Style','pushbutton',...
        'String','Analyze Features',...
        'Position',[450,450,150,40],...
        'Callback',@analyzeCallback);
    
    uicontrol('Parent',hFig, 'Style','pushbutton',...
        'String','Show Result',...
        'Position',[450,390,150,40],...
        'Callback',@resultCallback);
    
    % Create a text box to display the final analysis result.
    hResultText = uicontrol('Parent',hFig, 'Style','text',...
        'String','Result: ',...
        'Position',[450,320,400,50],...
        'FontSize',12,...
        'HorizontalAlignment','left');
    
    % Initialize a structure to store images, intermediate results, and analysis outcome.
    handles.image = [];
    handles.preprocessedImage = [];
    handles.cleanedImage = [];
    handles.analysisResult = '';
    handles.hAx = hAx;
    handles.hResultText = hResultText;
    guidata(hFig, handles);
    
    %% --- Callback Functions ---
    
    % Button 1: Upload Image
    function uploadImageCallback(~,~)
        % Let the user select an image file.
        [filename, pathname] = uigetfile({'*.*','All Files'});
        if isequal(filename,0)
            disp('User cancelled file selection.');
            return;
        end
        % Construct full file path and read the image.
        fullFileName = fullfile(pathname, filename);
        img = imread(fullFileName);
        handles = guidata(hFig);
        handles.image = img;
        guidata(hFig, handles);
        % Display the original image in the designated axes.
        axes(handles.hAx);
        imshow(img);
        title('Original Image');
    end

    % Button 2: Preprocess Image
    function preprocessCallback(~,~)
        handles = guidata(hFig);
        if isempty(handles.image)
            errordlg('Please upload an image first.');
            return;
        end
        
        img = handles.image;
        % Convert to grayscale if the image is in color.
        if size(img,3)==3
            grayImg = rgb2gray(img);
        else
            grayImg = img;
        end
        
        % -------------------------
        % Preprocessing Step 1: Contrast Enhancement
        % -------------------------
        % Use imadjust with stretchlim to enhance the contrast.
        % This improves the differentiation between text and background.
        contrastImg = imadjust(grayImg, stretchlim(grayImg), []);
        
        % -------------------------
        % Preprocessing Step 2: Noise Filtering
        % -------------------------
        % Apply adaptive median filtering (5x5 kernel) to reduce noise while preserving edges.
        filteredImg = medfilt2(contrastImg, [5 5]);
        
        % -------------------------
        % Preprocessing Step 3: Adaptive Thresholding
        % -------------------------
        % Calculate a locally adaptive threshold (sensitivity 0.65, larger neighborhood)
        % to robustly binarize the image despite variations in lighting.
        T = adaptthresh(filteredImg, 0.65, 'NeighborhoodSize', 35);
        bw = imbinarize(filteredImg, T);
        
        % -------------------------
        % Preprocessing Step 4: Morphological Processing
        % -------------------------
        % Use direction-aware morphological operations to remove noise and fill gaps.
        % se1 (horizontal) and se2 (vertical) structuring elements help preserve text structure.
        se1 = strel('rectangle',[3 1]);  % Emphasizes horizontal structures.
        se2 = strel('rectangle',[1 3]);  % Emphasizes vertical continuity.
        cleanedImg = imclose(imopen(bw, se1), se2);
        
        % Save the preprocessed and cleaned images.
        handles.preprocessedImage = bw;
        handles.cleanedImage = cleanedImg;
        guidata(hFig, handles);
        
        % Display each preprocessing step in a separate figure for documentation.
        figure('Name','Preprocessing Steps','NumberTitle','off');
        subplot(2,2,1); imshow(grayImg);      title('Grayscale Conversion');
        subplot(2,2,2); imshow(contrastImg);    title('Contrast Adjustment');
        subplot(2,2,3); imshow(filteredImg);    title('Median Filtering');
        subplot(2,2,4); imshow(cleanedImg);       title('Binarization & Morphological');
    end

    % Button 3: Analyze Features
    function analyzeCallback(~,~)
        handles = guidata(hFig);
        if isempty(handles.preprocessedImage)
            errordlg('Please preprocess the image first.');
            return;
        end
        
        % Use the cleaned binary image for analysis.
        bw = handles.cleanedImage;
        invBW = ~bw;  % Invert image so that text components are white on a dark background.
        
        % -------------------------
        % Feature Extraction: Connected Component Analysis
        % -------------------------
        % Identify connected components (text elements) using bwconncomp.
        CC = bwconncomp(invBW);
        stats = regionprops(CC, 'BoundingBox', 'Centroid', 'Area');
        
        % Remove small components considered as noise based on a minimum area threshold.
        minArea = max(50, size(bw,1)*size(bw,2)/1000);
        areas = [stats.Area];
        stats = stats(areas > minArea);
        
        if isempty(stats)
            errordlg('No valid text components detected.');
            return;
        end
        
        % -------------------------
        % Extract Metrics from Each Component
        % -------------------------
        % For each text component, extract its bounding box metrics.
        nComp = length(stats);
        heights     = zeros(1, nComp);
        topEdges    = zeros(1, nComp);
        bottomEdges = zeros(1, nComp);
        centersY    = zeros(1, nComp);
        
        for k = 1:nComp
            bb = stats(k).BoundingBox;
            heights(k)     = bb(4);      % Component height.
            topEdges(k)    = bb(2);      % Top edge (y-coordinate).
            bottomEdges(k) = bb(2) + bb(4);% Bottom edge (y-coordinate).
            centersY(k)    = stats(k).Centroid(2);
        end
        
        % -------------------------
        % Statistical Analysis of Component Heights
        % -------------------------
        % Calculate average height, standard deviation, and relative standard deviation.
        avgHeight = mean(heights);
        stdHeight = std(heights);
        relStd    = stdHeight / avgHeight;  % Lower relative std indicates uniformity.
        
        % -------------------------
        % Baseline Alignment Analysis (Uppercase Feature)
        % -------------------------
        % For uppercase text, components should have a consistent bottom alignment.
        medianBottom = median(bottomEdges);
        stdBottomAll = std(bottomEdges);
        validBottom  = bottomEdges(abs(bottomEdges - medianBottom) < 2*stdBottomAll);
        bottomLine   = mean(validBottom);
        bottomStd    = std(validBottom - bottomLine);
        bottomUniform= 1 / (1 + bottomStd);  % Higher uniformity yields a higher score.
        
        % Analyze top edges similarly to assess overall vertical alignment.
        medianTop = median(topEdges);
        stdTopAll = std(topEdges);
        validTop  = topEdges(abs(topEdges - medianTop) < 2*stdTopAll);
        topLine   = mean(validTop);
        topStd    = std(validTop - topLine);
        topUniform= 1 / (1 + topStd);
        
        % Combined alignment score (high alignment is expected for uppercase).
        alignmentScore = bottomUniform * topUniform; 
        
        % -------------------------
        % Outlier Analysis (Ascenders/Descenders in Lowercase)
        % -------------------------
        % Count components deviating significantly (>25%) from average height.
        outlierThreshold = 0.25;
        nonUniformCount = sum(abs(heights - avgHeight) > outlierThreshold * avgHeight);
        nonUniformRatio = nonUniformCount / nComp;
        
        % -------------------------
        % Scoring for Uppercase vs. Lowercase Classification
        % -------------------------
        % Uppercase scoring strongly favors uniform alignment (consistent baseline and top line)
        % while penalizing variability in heights.
        uppercaseScore = (alignmentScore^4.0) * ((1 - relStd)^0.2) * ((1 - nonUniformRatio)^0.2);
        
        % Lowercase scoring is more sensitive to height variation and non-uniformity,
        % as lowercase letters naturally exhibit ascenders and descenders.
        lowercaseScore = ((1 - alignmentScore)^1.5) * (relStd^1.3) * (nonUniformRatio^1.3);
        
        % Compare scores with a small threshold; if the difference is minimal, classify as mixed.
        diffThreshold = 0.02;
        scoreDiff = uppercaseScore - lowercaseScore;
        
        if abs(scoreDiff) < diffThreshold
            resultStr = 'Detected: Combination of Uppercase and Lowercase';
        elseif scoreDiff > 0
            resultStr = 'Detected: Uppercase';
        else
            resultStr = 'Detected: Lowercase';
        end
        
        % Save the analysis result for later display.
        handles.analysisResult = resultStr;
        guidata(hFig, handles);
        
        %% --- Visualization of Extracted Features ---
        % Generate additional visual outputs to support feature analysis.
        edges      = edge(bw, 'canny');      % Angular structures (favors uppercase)
        edgesSobel = edge(bw, 'sobel');       % Curvature analysis (favors lowercase)
        dt         = bwdist(~bw);            % Distance transform for stroke thickness
        
        % Create a figure with panels for uppercase, lowercase, and innovative features.
        featFig = figure('Name','Feature Extraction Steps','NumberTitle','off',...
            'Position',[100,100,1200,800]);
        
        %% Uppercase Features Panel
        % Uppercase handwriting is characterized by:
        % 1. Uniform baseline alignment.
        % 2. Consistent, uniform character height.
        % 3. Angular structures indicating straight, controlled strokes.
        upperPanel = uipanel('Parent', featFig, 'Title', 'Uppercase Features',...
            'FontSize', 12, 'Position', [0.05, 0.55, 0.9, 0.4]);
        tl_upper = tiledlayout(upperPanel,1,3,'TileSpacing','compact','Padding','compact');
        
        % Display original image with detected baseline.
        ax1 = nexttile(tl_upper);
        imshow(handles.image, 'Parent', ax1);
        title(ax1, 'Baseline Alignment');
        hold(ax1, 'on');
        yline(ax1, bottomLine, 'r', 'LineWidth',2);  % Draw the estimated baseline.
        hold(ax1, 'off');
        
        % Display histogram of character heights.
        ax2 = nexttile(tl_upper);
        histogram(ax2, heights, 'BinWidth',2, 'FaceColor',[0.2 0.4 0.6]);
        title(ax2, 'Height Distribution');
        xlabel(ax2, 'Pixel Height');
        ylabel(ax2, 'Frequency');
        
        % Display Canny edge map highlighting angular structures.
        ax3 = nexttile(tl_upper);
        imshow(edges, 'Parent', ax3);
        title(ax3, 'Angular Structures (Canny)');
        
        %% Lowercase Features Panel
        % Lowercase handwriting typically shows:
        % 1. Greater vertical variation due to ascenders and descenders.
        % 2. Presence of letters with significant deviations from the average height.
        % 3. More curved and rounded shapes (enhanced curvature).
        lowerPanel = uipanel('Parent', featFig, 'Title', 'Lowercase Features',...
            'FontSize', 12, 'Position', [0.05, 0.05, 0.9, 0.4]);
        tl_lower = tiledlayout(lowerPanel,1,3,'TileSpacing','compact','Padding','compact');
        
        % Display Sobel edge map to capture curvature.
        ax4 = nexttile(tl_lower);
        imshow(edgesSobel, 'Parent', ax4);
        title(ax4, 'Curvature Analysis (Sobel)');
        
        % Display stroke thickness map from the distance transform.
        ax5 = nexttile(tl_lower);
        imshow(dt, [], 'Parent', ax5);
        title(ax5, 'Stroke Thickness Map');
        colorbar(ax5);
        
        % Plot the vertical distribution of character centroids, showing vertical variation.
        ax6 = nexttile(tl_lower);
        plot(ax6, centersY, 'o-','LineWidth',1.5, 'MarkerFaceColor',[0.8 0.2 0.2]);
        title(ax6, 'Character Baseline Distribution');
        xlabel(ax6, 'Component Index');
        ylabel(ax6, 'Y-Centroid');
        grid(ax6, 'on');
    end

    % Button 4: Show Result
    function resultCallback(~,~)
        handles = guidata(hFig);
        if isempty(handles.analysisResult)
            errordlg('Please run the feature analysis first.');
            return;
        end
        % Update the text control and display a message box with the final classification.
        set(handles.hResultText, 'String', ['Result: ', handles.analysisResult]);
        msgbox(handles.analysisResult, 'Analysis Result', 'help');
    end
end
