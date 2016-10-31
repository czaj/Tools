function distribution = distType(input, fixed, length)
    
    if nargin == 3 && fixed == 1
        for i = 1:length
            distribution(i,1) = {'c'};
        end
    else
        for j = 1:size(input,2)
            for i = 1:size(input,1)
                switch input(i,j)
                    case 0
                        distribution(i,j) = {'n'};
                    case -1
                        distribution(i,j) = {'c'};
                    case 1
                        distribution(i,j) = {'l'};
                    case 2
                        distribution(i,j) = {'S'};
                    case 3
                        distribution(i,j) = {'t'};
                    case 4
                        distribution(i,j) = {'W'};
                    case 5
                        distribution(i,j) = {'s-a'};
                    case 6
                        distribution(i,j) = {'JSb'};
                    case 7
                        distribution(i,j) = {'JSu'};
                end
            end    
        end
    end
end