function ResultsOut = genOutput2(EstimOpt, Results, Head, Tail, Names, Template1, Template2, Heads)

head1 = {'var.', 'dist.', 'coef.','sign.' ,'st.err.' , 'p-value'};
head2 = {'coef.','sign.' ,'st.err.' , 'p-value'};

Dim1 = size(Template1,1);
Dim2 = size(Template1,2);
DimA = size(Template2,1);

Block = Results.(Template1{1,1});
RowOut = num2cell(Block);
RowOut(:,2) = star_sig_cell(Block(:,4));
RowOut = [Names.(Template1{1,1}), distType(Results.Dist), RowOut];
RowOut = [head1;RowOut];
HeadsTmp = cell(1,6);
HeadsTmp(1,3) = Heads.(Template1{1,1});
RowOut = [HeadsTmp; RowOut];

%HeadsOut = [Heads.(Template1{1,1})];
ResultsOut = [];
for i = 1:Dim1

    for j = 2:Dim2
        if ~isempty(Template1{i,j})
           Block = Results.(Template1{i,j});
           HeadsTmp = [];
           if size(Block,2) == 4
               ResultsTmp = num2cell(Block);
               ResultsTmp(:,2) = star_sig_cell(Block(:,4));
               ResultsTmp = [head2;ResultsTmp];
               HeadsTmp = cell(1,4);
               HeadsTmp(1,1) = Heads.(Template1{i,j});
               ResultsTmp = [HeadsTmp; ResultsTmp];
               %HeadsTmp = [HeadsTmp, Heads.(Template1{i,j})];
           else % This is for Xm, and other similar
               ResultsTmp = num2cell(Block);
               HeadsTmp = cell(1,size(Block,2));
               for l = 1:(size(Block,2)/4)
                   ResultsTmp(:,(l-1)*4+2) = star_sig_cell(Block(:,l*4));
                   HeadsTmp(1,4*l-3) = Heads.(Template1{i,j})(l);
               end
               ResultsTmp = [repmat(head2,1,size(Block,2)/4);ResultsTmp];
               ResultsTmp = [HeadsTmp; ResultsTmp];
               %HeadsTmp = [HeadsTmp, Heads.(Template1{i,j})'];
            end
           RowOut = [RowOut, ResultsTmp];
           %HeadsOut = [HeadsOut, HeadsTmp];
       end
    end
    
    MinVal = min(size(ResultsOut,2), size(RowOut,2));
    MaxVal = max(size(ResultsOut,2), size(RowOut,2));
    if MinVal == size(ResultsOut,2)
        ResTemp = cell(size(ResultsOut,1), MaxVal);
        ResTemp(:, 1:MinVal) = ResultsOut;
        ResultsOut = [ResTemp; RowOut];
    else
        ResTemp = cell(size(RowOut,1), MaxVal);
        ResTemp(:, 1:MinVal) = RowOut;
        ResultsOut = [ResultsOut; ResTemp];
    end
    if i ~= Dim1
        Block = Results.(Template1{i+1,1});
        if strcmp(Template1{i+1,1}, 'DetailsS')
            fixed = 1;
        end
        RowOut = num2cell(Block);
        RowOut(:,2) = star_sig_cell(Block(:,4));
        RowOut = [Names.(Template1{i+1,1}), distType(EstimOpt.Dist, fixed, size(Block,1)), RowOut]; %it will crash if size of the block and number of variables will differ
        RowOut = [head1;RowOut];
        HeadsTmp = cell(1,6);
        HeadsTmp(1,3) = Heads.(char(Template1{i+1,1}));
        RowOut = [HeadsTmp; RowOut];
    end
end

Changed = struct;
for i = 1:Dim1
    for j = 1:Dim2
        if ~isempty(Template1{i,j})
            if j>=2
                Blockh = Results.(Template1{i,j-1});
                Coords.(Template1{i,j}) = [Coords.(Template1{i,j-1})(1),Coords.(Template1{i,j-1})(2) + size(Blockh,2)];
                
            else
                if i>=2
                    Blockv = Results.(Template1{i-1,j});
                    Coords.(Template1{i,j}) = [Coords.(Template1{i-1,j})(1)+size(Blockv,1)+2,4*j-1];
                else
                    Coords.(Template1{i,j}) = [2+i,4*j-1];
                end 
            end
            Block = Results.(Template1{i,j});
            %for m=1:size(Block,2)/4
                for n = 1:size(Block,1)
                    if or(isnan(Block(n,1:4)) == [0 1 0 0],  isnan(Block(n,1:4)) == [0 0 0 0])
                        if isfield(Changed, Template1{i,j})
                            Changed.(Template1{i,j}) = [Changed.(Template1{i,j}), n];
                        else
                            Changed.(Template1{i,j}) = [n];    
                        end
                    end
                end
            %end
        end
    end
end

%ResultsOut(1+size(Results.(Template1{1,1}),1):end,:) =[ResultsOut(1+size(Results.(Template1{1,1}),1):end,1) cellstr(repmat(' ',size(ResultsOut,1) -size(Results.(Template1{1,1}),1) ,1)) ResultsOut(1+size(Results.(Template1{1,1}),1):end,2:end)];

if EstimOpt.Display~=0
    spacing = 2;
    precision = 4;

      
cprintf('*Black',strcat(Head{1,1} ,'\n'))
for i=1:DimA
    FirstBlock = Coords.(Template2{i,1})(1);
    [~,CW] = CellColumnWidth(ResultsOut(FirstBlock:FirstBlock+size(Results.(Template2{i,1}),1)-1,:));    
    indx = find(~cellfun(@isempty,Template2(i,:)));
    indx = indx(end);
    %UPPERHEADER
    fprintf('%*s',CW(1)+spacing+5+3,' ')
    for c =1:indx
        Y = Coords.(Template2{i,c})(2);
        for m=1:size(Results.(Template2{i,c}),2)/4
            name = Heads.(Template2{i,c});
            if iscell(name)
                name = name{m};
            end
            fprintf('%-*s',sum(CW(Y+(m-1)*4:Y+(m-1)*4+3)) - CW(Y+(m-1)*4+1) + (spacing+precision)*3 + 10, name)
        end
    end
    fprintf('\n')
    %\UPPERHEADER
    %HEADER
    fprintf('%-*s%-5s',CW(1)+spacing,ResultsOut{Coords.(Template2{i,1})(1) - 1,1}, ResultsOut{Coords.(Template2{i,1})(1) - 1,2})
    for c =1:indx
        X = Coords.(Template2{i,c})(1);
        Y = Coords.(Template2{i,c})(2);
        for m=1:size(Results.(Template2{i,c}),2)/4
            fprintf('%1s%*s%*s%*s%s', ' ',CW(Y+(m-1)*4)+spacing+precision,ResultsOut{X-1,Y+(m-1)*4}, CW(Y+(m-1)*4+2)+spacing+precision+4,ResultsOut{X-1,Y+(m-1)*4+2}, CW(Y+(m-1)*4+3)+spacing+precision+2,ResultsOut{X-1,Y+(m-1)*4+3},'   ')
        end
    end
    fprintf('\n')
    %\HEADER
    %VALUES
        if isfield (Changed, Template2(i,1))
            for k=1:size(Changed.(Template2{i,1}),2)
                d = Changed.(Template2{i,1})(k);
                fprintf('%-*s%-4s', CW(1)+spacing+1,ResultsOut{Coords.(Template2{i,1})(1) + d - 1,1}, ResultsOut{Coords.(Template2{i,1})(1) + d - 1,2})
                for c =1:indx
                    for m=1:size(Results.(Template2{i,c}),2)/4
                        X = Coords.(Template2{i,c})(1);
                        Y = Coords.(Template2{i,c})(2);
                        fprintf('% *.*f%-3s% *.*f% *.*f%s', CW(Y+(m-1)*4)+spacing+precision+1,precision,ResultsOut{X+d-1,Y+(m-1)*4}, ResultsOut{X+d-1,Y+1+(m-1)*4}, CW(Y+(m-1)*4+2)+spacing+precision+1,precision,ResultsOut{X+d-1,Y+2+(m-1)*4}, CW(Y+3+(m-1)*4)+spacing+precision+2,precision,ResultsOut{X+d-1,Y+3+(m-1)*4},'   ')
                    end
                end
                fprintf('\n')
            end
        else
            for d=1:size(Results.(Template2{i,1}),1)
                fprintf('%-*s%-4s', CW(1)+spacing+1,ResultsOut{Coords.(Template2{i,1})(1) + d - 1,1}, ResultsOut{Coords.(Template2{i,1})(1) + d - 1,2})
                for c =1:indx
                    for m=1:size(Results.(Template2{i,c}),2)/4
                        X = Coords.(Template2{i,c})(1);
                        Y = Coords.(Template2{i,c})(2);
                        fprintf('% *.*f%-3s% *.*f% *.*f%s', CW(Y+(m-1)*4)+spacing+precision+1,precision,ResultsOut{X+d-1,Y+(m-1)*4}, ResultsOut{X+d-1,Y+1+(m-1)*4}, CW(Y+(m-1)*4+2)+spacing+precision+1,precision,ResultsOut{X+d-1,Y+2+(m-1)*4}, CW(Y+3+(m-1)*4)+spacing+precision+2,precision,ResultsOut{X+d-1,Y+3+(m-1)*4},'   ')
                    end
                end
                fprintf('\n')
            end
        end
        disp(' ');        
end
    %\VALUES
    [~,CWm] = CellColumnWidth(num2cell(Results.stats));
    cprintf('*Black', 'Model characteristics: \n')
    fprintf('%-29s%*.*f\n', 'LL at convergence:',CWm(1)+spacing+precision+1,precision, Results.stats(1))
    fprintf('%-29s%*.*f\n', 'LL at constant(s) only:',CWm(1)+spacing+precision+1,precision, Results.stats(2))
    fprintf('%-29s%*.*f\n', strcat('McFadden''s pseudo-R',char(178),':'),CWm(1)+spacing+precision+1,precision, Results.stats(3))
    fprintf('%-29s%*.*f\n', strcat('Ben-Akiva-Lerman''s pseudo-R',char(178),':'),CWm(1)+spacing+precision+1,precision, Results.stats(4))
    fprintf('%-29s%*.*f\n','AIC/n:',CWm(1)+spacing+precision+1,precision, Results.stats(5))
    fprintf('%-29s%*.*f\n','BIC/n:',CWm(1)+spacing+precision+1,precision, Results.stats(6))
    fprintf('%-29s%*.*f\n','n (observations):',CWm(1)+spacing,0, Results.stats(7))
    fprintf('%-29s%*.*f\n','r (respondents):',CWm(1)+spacing,0, Results.stats(8))
    fprintf('%-29s%*.*f\n','k (parameters):',CWm(1)+spacing,0, Results.stats(9))
    disp(' ')
    for i = 11:size(Tail,1)
        fprintf('%-23s%-s\n', Tail{i,1}, Tail{i,2})
    end
    
    disp(' ')
        clocknote = clock;
        tocnote = toc;
        [~,DayName] = weekday(now,'long');
        disp(['Estimation completed on ' DayName ', ' num2str(clocknote(1)) '-' sprintf('%02.0f',clocknote(2)) '-' sprintf('%02.0f',clocknote(3)) ' at ' sprintf('%02.0f',clocknote(4)) ':' sprintf('%02.0f',clocknote(5)) ':' sprintf('%02.0f',clocknote(6))])
        disp(['Estimation took ' num2str(tocnote) ' seconds ('  num2str(floor(tocnote/(60*60))) ' hours ' num2str(floor(rem(tocnote,60*60)/60)) ' minutes ' num2str(rem(tocnote,60)) ' seconds).']);
    
end


% Adding head and tail

Indx = size(ResultsOut,2);
HeadOut = cell(size(Head,1), Indx);
HeadOut(:,1:2) = Head;
ResultsOut = [HeadOut; ResultsOut];
%ResultsOut(2,3:4:end) = HeadsOut;
TailOut = cell(size(Tail,1), Indx);
TailOut(:,1:2) = Tail;
ResultsOut = [ResultsOut; TailOut];

