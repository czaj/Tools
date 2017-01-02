function distribution = distType(input, fixed, input_length)

if nargin == 3 && fixed == 1
    distribution = cell(input_length,1);
%     for i = 1:input_length
%         distribution(i,1) = {' '};
%     end
else
    distribution = cell(length(input),1);
    for i = 1:length(input)
        switch input(i)
            case 0
                distribution(i,1) = {'n'};
            case -1
                distribution(i,1) = {'f'};
            case 1
                distribution(i,1) = {'l'};
            case 2
                distribution(i,1) = {'S'};
            case 3
                distribution(i,1) = {'t'};
            case 4
                distribution(i,1) = {'W'};
            case 5
                distribution(i,1) = {'s-a'};
            case 6
                distribution(i,1) = {'JSb'};
            case 7
                distribution(i,1) = {'JSu'};
        end
    end
    %         for j = 1:size(input,2)
    %             for i = 1:size(input,1)
    %                 switch input(i,j)
    %                     case 0
    %                         distribution(i,j) = {'n'};
    %                     case -1
    %                         distribution(i,j) = {'f'};
    %                     case 1
    %                         distribution(i,j) = {'l'};
    %                     case 2
    %                         distribution(i,j) = {'S'};
    %                     case 3
    %                         distribution(i,j) = {'t'};
    %                     case 4
    %                         distribution(i,j) = {'W'};
    %                     case 5
    %                         distribution(i,j) = {'s-a'};
    %                     case 6
    %                         distribution(i,j) = {'JSb'};
    %                     case 7
    %                         distribution(i,j) = {'JSu'};
    %                 end
    %             end
    %         end
end

end