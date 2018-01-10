function distribution = distType(input, fixed, input_length, type)

if nargin == 4 && strcmp(type,'lml')
    distribution = cell(length(input),1);
    for i = 1:length(input)
        switch input(i)
            case 0
                distribution(i,1) = {'a n'};
            case -1
                distribution(i,1) = {'f'};
            case 1
                distribution(i,1) = {'a l'};
            case 2
                distribution(i,1) = {'LP (n)'};
            case 3
                distribution(i,1) = {'LP (ln)'};
            case 4
                distribution(i,1) = {'Sf'};
            case 5
                distribution(i,1) = {'LSp'};
            case 6
                distribution(i,1) = {'CSp'};
            case 7
                distribution(i,1) = {'Pw CSp'};
            case 8
                distribution(i,1) = {'Pw CHISp'};
        end
    end
elseif nargin == 3 && fixed == 1
    distribution = cell(input_length,1);
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
end

end