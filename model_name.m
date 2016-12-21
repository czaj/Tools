function model = model_name(x)

    switch x 
        case 0
            model = 'OLS';
        case 1
            model = 'MNL';   
        case 2 
            model = 'OP';        
        case 3 
            model = 'POISS';            
        case 4 
            model = 'NB';                
        case 5
            model = 'ZIP';
        case 6
            model = 'ZINB';
    end
end